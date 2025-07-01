#!/bin/bash

# === KONFIGURASI ===
DOMAIN="riyan123.ip-ddns.com"         # Domain utama yang dipakai client
NS_DOMAIN="dns.riyan123.ip-ddns.com"  # Subdomain sebagai NS, harus A record ke IP VPS
TUN_IP="10.0.0.1"                     # IP tunnel (interface dns0)
PASSWORD="Saputra456"             # Password iodine
TUN_NET="10.0.0.0/24"                # Subnet virtual client

# === DETEKSI INTERFACE INTERNET ===
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
echo "[+] Interface internet: $IFACE"

# === INSTALL DEPENDENSI ===
echo "[+] Install iodine dan iptables"
apt update
apt install -y iodine iptables-persistent resolvconf

# === BUKA PORT 53/UDP (JIKA PAKAI UFW) ===
if command -v ufw &> /dev/null; then
    echo "[+] Buka port UDP 53 (DNS)"
    ufw allow 53/udp
    ufw reload || true
fi

# === ENABLE IP FORWARDING ===
echo "[+] Aktifkan IP forwarding"
sysctl -w net.ipv4.ip_forward=1
sed -i 's|#*net.ipv4.ip_forward=.*|net.ipv4.ip_forward=1|' /etc/sysctl.conf

# === KONFIGURASI NAT & DNS REDIRECTION ===
echo "[+] Konfigurasi NAT dan routing dns0"
iptables -t nat -A POSTROUTING -s $TUN_NET -o $IFACE -j MASQUERADE
iptables -A FORWARD -i dns0 -o $IFACE -j ACCEPT
iptables -A FORWARD -i $IFACE -o dns0 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -A PREROUTING -i dns0 -p udp --dport 53 -j DNAT --to-destination 8.8.8.8

mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# === BUAT SERVICE IODINED ===
echo "[+] Membuat systemd service untuk iodined"
cat > /etc/systemd/system/iodined.service <<EOF
[Unit]
Description=Iodine DNS Tunnel Server
After=network.target

[Service]
ExecStart=/usr/sbin/iodined -f -P $PASSWORD $TUN_IP $DOMAIN
ExecStartPost=/bin/sh -c '/usr/sbin/iptables-restore < /etc/iptables/rules.v4'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# === AKTIFKAN SERVICE ===
echo "[+] Mengaktifkan service iodined"
systemctl daemon-reload
systemctl enable iodined
systemctl restart iodined

# === OUTPUT SUKSES ===
echo ""
echo "✅ SETUP BERHASIL!"
echo "🌐 Domain Utama : $DOMAIN"
echo "🧠 NS Record    : $DOMAIN NS → $NS_DOMAIN"
echo "📌 A Record     : $NS_DOMAIN → IP VPS kamu"
echo "🔐 Password     : $PASSWORD"
echo ""
echo "💡 Tes dari client:"
echo "    iodine -P $PASSWORD $DOMAIN"
echo "    ip route add default dev dns0"
