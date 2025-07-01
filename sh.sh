#!/bin/bash

# === KONFIGURASI ===
DOMAIN="riyan123.ip-ddns.com"         # Domain utama YANG akan langsung dipakai client
NS_DOMAIN="dns.riyan123.ip-ddns.com"  # Subdomain yang jadi NS, diarahkan ke IP VPS
TUN_IP="10.0.0.1"                     # IP untuk tunnel DNS (dns0 interface)
PASSWORD="bebasinternet"             # Password iodine
TUN_NET="10.0.0.0/24"                # Jaringan virtual untuk client

# === DETEKSI INTERFACE INTERNET ===
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
echo "[+] Interface internet terdeteksi: $IFACE"

# === INSTALL DEPENDENSI ===
echo "[+] Install iodine dan iptables"
apt update
apt install -y iodine iptables-persistent resolvconf ufw

# === BUKA PORT UDP 53 ===
echo "[+] Buka port UDP 53 (DNS)"
ufw allow 53/udp
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
iptables -t nat -A PREROUTING -i dns0 -p udp --dport 53 -j DNAT --to-destination 8.8.8.8
iptables-save > /etc/iptables/rules.v4

# === BUAT SERVICE SYSTEMD UNTUK IODINED ===
echo "[+] Buat systemd service iodined"
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

# === AKTIFKAN DAN JALANKAN SERVICE ===
echo "[+] Aktifkan service iodined"
systemctl daemon-reload
systemctl enable iodined
systemctl restart iodined

# === INFO FINAL ===
echo ""
echo "✅ SETUP BERHASIL!"
echo "🌐 Domain Utama : $DOMAIN"
echo "🧠 NS Record    : $DOMAIN NS → $NS_DOMAIN"
echo "📌 A Record     : $NS_DOMAIN → IP VPS kamu"
echo "🔐 Password     : $PASSWORD"
echo ""
echo "💡 Tes client:"
echo "    iodine -P $PASSWORD $DOMAIN"
echo "    ip route add default dev dns0"
