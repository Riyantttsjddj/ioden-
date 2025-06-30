#!/bin/bash

# === Konfigurasi ===
SUBDOMAIN="dns.riyan123.ip-ddns.com"   # Ganti sesuai subdomain kamu
PASSWORD="saputra456"                  # Ganti sesuai kebutuhan
TUN_IP="10.0.0.1"                      # IP tunnel server
PORT="53"

echo "[✓] Setup Iodine (Versi Lama - Kompatibel)"

# === Install iodine dari repo (versi lama) ===
apt update && apt install iodine -y || { echo "Gagal install iodine"; exit 1; }

# === Aktifkan IP forwarding ===
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i '/^#\?net.ipv4.ip_forward/s/^#//' /etc/sysctl.conf
sysctl -p

# === Buka port UDP 53 (jika UFW aktif) ===
if command -v ufw >/dev/null 2>&1; then
    ufw allow $PORT/udp || echo "[!] Gagal buka port via ufw"
fi

# === Hentikan iodined lama jika ada ===
pkill iodined 2>/dev/null

# === Buat systemd service baru ===
cat <<EOF > /etc/systemd/system/iodine.service
[Unit]
Description=Iodine DNS Tunnel Server (Versi Lawas)
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

# === Informasi koneksi untuk klien ===
echo -e "\n[✓] Iodine Server aktif! Gunakan perintah ini di klien:"
echo "iodine -f -z -m 1000 -P $PASSWORD $SUBDOMAIN"
echo -e "\nServer IP Tunnel: $TUN_IP → Klien akan mendapat 10.0.0.2"
