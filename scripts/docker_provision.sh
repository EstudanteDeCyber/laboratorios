#!/bin/bash
## Ajuste timezone
timedatectl set-timezone America/Sao_Paulo

## Update da maquina virtual
apt update && apt-mark hold openssh-server
NEEDRESTART_MODE=a apt -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" upgrade 

## Verificando e removendo instalação antiga do Docker, caso haja
echo
echo "Verificando e removendo instalação antiga do Docker, caso haja..."
echo
## Remover possíveis instalações antigas de Docker
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  sudo apt-get remove -y $pkg || true
done

## Instalar PRÉ-REQUISITOS
echo
echo "Instalação de pacotes pre-requisitos..."
echo
apt install -y htop unzip curl git ca-certificates lsb-release gnupg docker-compose

## Instalar Docker via script oficial
echo
echo "Instalacao do Docker do repositorio oficial..."
echo
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

## Iniciar e habilitar Docker
echo
echo "Iniciando Docker..."
echo
sudo systemctl start docker
sudo systemctl enable docker
usermod -aG docker vagrant

## Aguardar o Docker subir
sleep 10
