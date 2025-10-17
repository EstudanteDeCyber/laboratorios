#!/bin/bash

# ===============================================================
# Remove versões antigas do Docker, se existirem
# ===============================================================
echo
echo "# ==============================================================="
echo "# Verificando e removendo instalação antiga do Docker, caso haja..."
echo "# ==============================================================="
echo

for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  sudo apt-get remove -y $pkg || true
done

# ===============================================================
# Instala pacotes pré-requisitos
# ===============================================================
echo
echo "# ==============================================================="
echo "# Instalação de pacotes pré-requisitos"
echo "# ==============================================================="
echo

apt install -y htop unzip curl git ca-certificates lsb-release gnupg jq

# ===============================================================
# Instala e configura o Chrony (NTP)
# ===============================================================
echo
echo "# ==============================================================="
echo "# Instalando e configurando Chrony para sincronização com ntp.br"
echo "# ==============================================================="
echo

# Desativa o serviço padrão de sincronização de tempo
sudo timedatectl set-ntp false

# Remove arquivo de configuração antigo (caso exista)
rm -f /etc/chrony/chrony.conf

# Instala Chrony
apt install -y chrony

# Configura servidores NTP do Brasil
echo "server ntp.br iburst" | sudo tee /etc/chrony/chrony.conf

# Reinicia e habilita o serviço Chrony
sudo systemctl restart chrony
sudo systemctl enable chrony

# Verifica status da sincronização
chronyc sources

# ===============================================================
# Instala Docker a partir do script oficial
# ===============================================================
echo
echo "# ==============================================================="
echo "# Instalação do Docker via repositório oficial"
echo "# ==============================================================="
echo

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# ===============================================================
# Inicia e habilita o serviço Docker
# ===============================================================
echo
echo "# ==============================================================="
echo "# Iniciando e habilitando serviço Docker"
echo "# ==============================================================="
echo

sudo systemctl start docker
sudo systemctl enable docker

# Adiciona o usuário 'vagrant' ao grupo 'docker'
usermod -aG docker vagrant

# Instala docker-compose
sudo apt install -y docker-compose

# ===============================================================
# Aguarda o Docker iniciar completamente
# ===============================================================
sleep 10