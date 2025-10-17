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