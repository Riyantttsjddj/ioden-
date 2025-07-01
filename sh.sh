#!/bin/bash

# === KONFIGURASI DOMAIN & TUNNEL ===
DOMAIN="riyan123.ip-ddns.com"              # Domain utama (digunakan client)
NS_DOMAIN="riyan200324.duckdns.org"        # Subdomain untuk NS → arahkan ke IP VPS
TUN_IP="10.0.0.1"
TUN_NET="10.0.0.0/24"
PASSWORD="saputra456"

# === DETEKSI INTERFACE INTERNET ===
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
echo "[+] Interface internet terdeteksi: $IFACE"

# === HAPUS KONFIGURASI LAMA (jika ada) ===
echo "[+] Bersihkan setup lama jika ada..."
systemctl stop iodined 2>/dev/null
systemctl disable iodined 2>/dev/null
rm -f /etc/systemd/system/iodined.service
rm -f /etc/iptables/rules.v4
ip link delete dns0 2>/dev/null

# === INSTALL DEPENDENSI ===
echo "[+] Install iodine dan iptables"
apt update
DEBIAN_FRONTEND=noninteractive apt install -y iodine iptables-persistent resolvconf ufw

# === BUKA PORT UDP 53 ===
echo "[+] Buka port UDP 53 (DNS)"
ufw allow 53/udp
ufw --force enable
ufw reload

# === AKTIFKAN IP FORWARDING ===
echo "[+] Aktifkan IP Forwarding"
sysctl -w net.ipv4.ip_forward=1
sed -i 's|#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|' /etc/sysctl.conf

# === ATUR IPTABLES (NAT & ROUTING) ===
echo "[+] Konfigurasi NAT dan routing dns0"
iptables -t nat -A POSTROUTING -s $TUN_NET -o $IFACE -j MASQUERADE
iptables -A FORWARD -i dns0 -o $IFACE -j ACCEPT
iptables -A FORWARD -i $IFACE -o dns0 -m state --state ESTABLISHED,RELATED -j ACCEPT
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# === BUAT SERVICE SYSTEMD UNTUK IODINED ===
echo "[+] Buat systemd service iodined"
cat > /etc/systemd/system/iodined.service <<EOF
[Unit]
Description=Iodine DNS Tunnel Server
After=network.target

[Service]
ExecStart=/usr/sbin/iodined -f -c -P $PASSWORD $TUN_IP $DOMAIN
ExecStartPost=/bin/bash -c 'test -f /etc/iptables/rules.v4 && iptables-restore < /etc/iptables/rules.v4 || true'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# === AKTIFKAN DAN JALANKAN SERVICE ===
echo "[+] Aktifkan service iodined"
systemctl daemon-reload
systemctl enable iodined
systemctl restart iodined

# === CEK STATUS ===
sleep 1
echo ""
systemctl is-active --quiet iodined && STATUS="✅ AKTIF" || STATUS="❌ GAGAL"

# === INFO FINAL ===
echo ""
echo "✅  SETUP SELESAI!"
echo "🌐 Domain: $DOMAIN"
echo "🔐 Password: $PASSWORD"
echo "🧠 NS: $DOMAIN NS → $NS_DOMAIN"
echo "📌 A: $NS_DOMAIN → IP VPS kamu"
echo ""
echo "📡 Status Service: $STATUS"
echo ""
echo "💡 Tes dari client:"
echo "    iodine -P $PASSWORD $DOMAIN"
echo "    ip route add default dev dns0"
