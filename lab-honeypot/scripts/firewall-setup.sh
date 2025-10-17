#!/usr/bin/env bash
set -euo pipefail

SRC_FIREWALL="/vagrant/scripts/firewall.sh"
DST_FIREWALL="/etc/firewall.sh"
SERVICE_FILE="/etc/systemd/system/firewall.service"

echo "==> Iniciando setup do firewall"

if [ ! -f "$SRC_FIREWALL" ]; then
  echo "ERRO: $SRC_FIREWALL não encontrado."
  exit 1
fi

echo "==> Copiando $SRC_FIREWALL para $DST_FIREWALL"
cp -f "$SRC_FIREWALL" "$DST_FIREWALL"

echo "==> Ajustando permissões"
chown root:root "$DST_FIREWALL"
chmod 755 "$DST_FIREWALL"

echo "==> Criando unit file $SERVICE_FILE"
cat > "$SERVICE_FILE" <<'EOF'
[Unit]
Description=Firewall script service
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/firewall.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "==> Recarregando systemd"
systemctl daemon-reload

echo "==> Habilitando firewall.service"
systemctl enable firewall.service

#echo "==> Iniciando firewall.service"
#systemctl start firewall.service

echo "==> Status do firewall.service:"
systemctl --no-pager status firewall.service || true

# ===============================================================
# SSH Config
# ===============================================================
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^PubkeyAuthentication yes/#PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
echo "vagrant:vagrant" | chpasswd

# ===============================================================
# Ajustar Placa de REDE para o IP específico
# ===============================================================
cp /etc/network/interfaces /etc/network/interfaces.bak || true
cat << 'EONET' > /etc/network/interfaces
auto lo
iface lo inet loopback

# INTERNET
auto eth0
iface eth0 inet dhcp

# DMZ
auto eth1
iface eth1 inet static
address 192.168.50.1
gateway 192.168.50.1
netmask 255.255.255.0

# LAN
auto eth2
iface eth2 inet static
address 20.20.20.1
gateway 20.20.20.1
netmask 255.255.255.0

# WAN
auto eth4
iface eth0 inet static
address 192.168.56.254
netmask 255.255.255.0
EONET

echo "==> Setup do firewall concluído"