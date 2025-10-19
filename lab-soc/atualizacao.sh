#!/bin/bash

# ===============================================================
# Ajusta timezone para America/Sao_Paulo
# ===============================================================
timedatectl set-timezone America/Sao_Paulo

# ===============================================================
# Define ambiente nao interativo para instalacoes
# ===============================================================
export DEBIAN_FRONTEND=noninteractive

# ===============================================================
# Atualiza lista de pacotes
# ===============================================================
apt-get update -y

# ===============================================================
# Instala OpenSSH se nao estiver presente
# ===============================================================
if ! dpkg -s openssh-server >/dev/null 2>&1; then
  apt-get install -y --no-install-recommends openssh-server
fi

# ===============================================================
# Upgrade do sistema (aceita novas configuracoes)
# ===============================================================
echo
echo "# ==============================================================="
echo "# Upgrade do sistema (aceita novas configuracoes)"
echo "# ==============================================================="
echo

apt-get -y -o Dpkg::Options::="--force-confdef" \
         -o Dpkg::Options::="--force-confnew" upgrade

# ===============================================================
# Reinicia o servico SSH com fallback
# ===============================================================
if systemctl list-units --full -all | grep -q "^ssh.service"; then
  systemctl restart ssh.service
elif systemctl list-units --full -all | grep -q "^sshd.service"; then
  systemctl restart sshd.service
elif [ -x /etc/init.d/ssh ]; then
  /etc/init.d/ssh restart
elif [ -x /etc/init.d/sshd ]; then
  /etc/init.d/sshd restart
else
  echo "Aviso: nenhum servico de SSH encontrado para reiniciar."
fi

# ===============================================================
# Limpeza de pacotes desnecessarios
# ===============================================================
apt-get autoremove -y
apt-get clean

# ===============================================================
# Configuracoes do servidor SSH
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

# ===============================================================
# Define senha padrao para o usuario vagrant
# ===============================================================
echo "vagrant:vagrant" | chpasswd