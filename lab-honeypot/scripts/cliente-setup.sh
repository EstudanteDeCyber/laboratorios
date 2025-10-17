#!/usr/bin/env bash

set -euo pipefail

# ===============================================================
# Configuração do SSH
# ===============================================================
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Permitir autenticação por senha
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^PubkeyAuthentication yes/#PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Reinicia o serviço SSH com fallback novamente
if systemctl list-units --full -all | grep -q "^ssh.service"; then
  systemctl restart ssh.service
elif systemctl list-units --full -all | grep -q "^sshd.service"; then
  systemctl restart sshd.service
elif [ -x /etc/init.d/ssh ]; then
  /etc/init.d/ssh restart
elif [ -x /etc/init.d/sshd ]; then
  /etc/init.d/sshd restart
else
  echo "Aviso: nenhum serviço de SSH encontrado para reiniciar."
fi

# Altera a senha do usuário vagrant
echo "vagrant:vagrant" | chpasswd

# ===============================================================
# Configuração de Rede Estática
# ===============================================================
cp /etc/network/interfaces /etc/network/interfaces.bak || true

cat << 'EONET' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 20.20.20.11
    netmask 255.255.255.0

# Interface de rede alternativa comentada
# auto eth0
# iface eth0 inet static
#     address 192.168.50.51
#     netmask 255.255.255.0
EONET