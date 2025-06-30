#!/bin/bash

# === Konfigurasi ===
SUBDOMAIN="dns.riyan123.ip-ddns.com"  # Subdomain kamu
PASSWORD="saputra456"                 # Password koneksi
TUN_IP="10.0.0.1"                     # IP sisi server (jangan ubah)
TTL="127"                             # TTL DNS agar terlihat natural
PORT="53"                             # Port DNS standar

echo "[✓] Setup Iodine DNS Tunnel - Anti-DPI Final"

# === Update & install iodine ===
apt update -y && apt install -y iodine || { echo "Install iodine gagal."; exit 1; }

# === Aktifkan IP forwarding ===
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i '/^#\?net.ipv4.ip_forward/s/^#//' /etc/sysctl.conf
sysctl -p

# === Buka port UDP 53 jika UFW aktif ===
if command -v ufw >/dev/null 2>&1; then
    ufw allow $PORT/udp || echo "[!] UFW gagal, buka port manual jika perlu"
fi

# === Hentikan iodined sebelumnya ===
pkill iodined 2>/dev/null

# === Buat systemd service ===
cat <<EOF > /etc/systemd/system/iodine.service
[Unit]
Description=Iodine DNS Tunnel Server (Anti-DPI Final)
After=network.target

[Service]
ExecStart=/usr/sbin/iodined -f -c -n -z -m 1000 -O 0 --ttl $TTL -P $PASSWORD $TUN_IP $SUBDOMAIN
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# === Jalankan service ===
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable iodine.service
systemctl restart iodine.service

# === Info koneksi untuk klien ===
echo -e "\n[✓] Iodine aktif! Gunakan perintah di klien (Termux/PC):"
echo "iodine -f -n -z -m 1000 -O 0 --ttl $TTL -P $PASSWORD $SUBDOMAIN"
echo -e "\nServer IP Tunnel: $TUN_IP (Client akan dapat: 10.0.0.2)"
