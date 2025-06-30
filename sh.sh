#!/bin/bash

# === Konfigurasi ===
SUBDOMAIN="dns.riyan123.ip-ddns.com"   # Subdomain DNS Tunnel
PASSWORD="saputra456"                  # Password koneksi
TUN_IP="10.0.0.1/24"                   # IP Tunnel + CIDR
PORT="53"                              # Port DNS standar (UDP)

echo "[✓] Setup Iodine Server (Kompatibel Versi Lama)"

# === Install iodine dari repo bawaan ===
apt update && apt install -y iodine || { echo "Gagal install iodine"; exit 1; }

# === Aktifkan IP forwarding untuk routing ==
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i '/^#\?net.ipv4.ip_forward/s/^#//' /etc/sysctl.conf
sysctl -p

# === Buka port UDP 53 jika UFW aktif ===
if command -v ufw >/dev/null 2>&1; then
    ufw allow $PORT/udp || echo "[!] UFW gagal, buka port manual jika perlu"
fi

# === Hentikan iodined lama (kalau ada) ===
pkill iodined 2>/dev/null

# === Buat systemd service ===
cat <<EOF > /etc/systemd/system/iodine.service
[Unit]
Description=Iodine DNS Tunnel Server (Kompatibel)
After=network.target

[Service]
ExecStart=/usr/sbin/iodined -f -c -z -m 1000 -P $PASSWORD $TUN_IP $SUBDOMAIN
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# === Jalankan dan aktifkan service ===
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable iodine.service
systemctl restart iodine.service

# === Info akhir ===
echo -e "\n[✓] Iodine Server aktif!"
echo "Gunakan perintah ini di klien (Termux/PC):"
echo "iodine -f -z -m 1000 -P $PASSWORD $SUBDOMAIN"
echo -e "\nTunnel Server IP: ${TUN_IP%/*} (Client akan dapat: 10.0.0.2)"
