#!/bin/bash

# === KONFIGURASI ===
DOMAIN="riyan123.ip-ddns.com"
NS_DOMAIN="riyan200324.duckdns.org"
TUN_IP="10.0.0.1"
PASSWORD="saputra456"
TUN_NET="10.0.0.0/24"

# === DETEKSI INTERFACE INTERNET ===
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
echo "[+] Interface internet terdeteksi: $IFACE"

# === HAPUS FILE SETUP LAMA (JIKA ADA) ===
SCRIPT_NAME="setup_iodine.sh"
if [[ -f "$SCRIPT_NAME" ]]; then
    echo "[+] Menghapus file setup lama: $SCRIPT_NAME"
    rm -f "$SCRIPT_NAME"
fi

# === INSTALL DEPENDENSI ===
echo "[+] Install iodine dan iptables"
apt update
DEBIAN_FRONTEND=noninteractive apt install -y iodine resolvconf iptables iptables-persistent

# === AKTIFKAN IP FORWARDING ===
echo "[+] Aktifkan IP forwarding"
sysctl -w net.ipv4.ip_forward=1
sed -i 's|#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|' /etc/sysctl.conf

# === KONFIGURASI IPTABLES ===
echo "[+] Setup iptables NAT & routing"
iptables -t nat -A POSTROUTING -s $TUN_NET -o $IFACE -j MASQUERADE
iptables -A FORWARD -i dns0 -o $IFACE -j ACCEPT
iptables -A FORWARD -i $IFACE -o dns0 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -A PREROUTING -i dns0 -p udp --dport 53 -j DNAT --to-destination 8.8.8.8

mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# === BUAT SERVICE SYSTEMD UNTUK IODINED ===
echo "[+] Buat service systemd iodined"
cat > /etc/systemd/system/iodined.service <<EOF
[Unit]
Description=Iodine DNS Tunnel Server
After=network.target

[Service]
ExecStart=/usr/sbin/iodined -f -P $PASSWORD $TUN_IP $DOMAIN
ExecStartPost=/usr/sbin/iptables-restore < /etc/iptables/rules.v4
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# === ENABLE & START SERVICE ===
echo "[+] Aktifkan service iodined"
systemctl daemon-reload
systemctl enable iodined
systemctl restart iodined

# === INFORMASI FINAL ===
echo ""
echo "✅ SETUP SELESAI!"
echo "🌐 Domain: $DOMAIN"
echo "🔐 Password: $PASSWORD"
echo "📡 NS: $DOMAIN NS → $NS_DOMAIN"
echo "📌 A: $NS_DOMAIN → IP VPS"
echo ""
echo "💡 Tes dari client:"
echo "    iodine -P $PASSWORD $DOMAIN"
echo "    ip route add default dev dns0"
