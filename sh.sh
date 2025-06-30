#!/bin/bash

# === Konfigurasi ===
SUBDOMAIN="dns.riyan123.ip-ddns.com"   # Subdomain DNS Tunnel
PASSWORD="saputra456"                  # Password koneksi
TUN_IP="10.0.0.1"                      # IP Tunnel server
PORT="53"                              # Port DNS

echo "[✓] Memulai setup Iodine DNS Tunnel Server (Versi Stabil)"

# === Install iodine dari repo resmi ===
apt update && apt install -y iodine || {
    echo "[✗] Gagal menginstall iodine"; exit 1;
}

# === Aktifkan IP forwarding untuk internet sharing ===
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i '/^#\?net.ipv4.ip_forward/s/^#//' /etc/sysctl.conf
sysctl -p

# === Buka port 53 UDP jika UFW aktif ===
if command -v ufw >/dev/null 2>&1; then
    ufw allow $PORT/udp || echo "[!] UFW gagal buka port, cek manual jika perlu"
fi

# === Hentikan iodined jika sedang berjalan ===
pkill iodined 2>/dev/null

# === Tambahkan NAT agar klien bisa internetan lewat DNS tunnel ===
# Ganti 'eth0' dengan interface utama kamu jika berbeda
INTF=$(ip route | grep default | awk '{print $5}')
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o "$INTF" -j MASQUERADE

# === Buat systemd service ===
cat <<EOF > /etc/systemd/system/iodine.service
[Unit]
Description=Iodine DNS Tunnel Server (Stabil)
After=network.target

[Service]
ExecStart=/usr/sbin/iodined -f -c -P $PASSWORD $TUN_IP $SUBDOMAIN
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# === Aktifkan dan jalankan service ===
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable iodine.service
systemctl restart iodine.service

# === Informasi koneksi ===
echo -e "\n[✓] Iodine Server aktif dan siap digunakan!"
echo "Gunakan perintah ini di klien (Termux/PC):"
echo -e "\niodine -f -P $PASSWORD $SUBDOMAIN\n"
echo "Server Tunnel IP: $TUN_IP (Client akan mendapat: 10.0.0.2)"
