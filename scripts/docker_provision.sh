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
echo "Instalacao de pacotes pre-requisitos..."
echo
apt install -y htop unzip curl git ca-certificates lsb-release gnupg jq

## Adicionando a instalação e configuração do Chrony
echo
echo "Instalando e configurando Chrony para sincronizar com ntp.br..."
echo
# Parar o serviço padrão de sincronização de tempo para evitar conflito
sudo timedatectl set-ntp false
# Remover o arquivo de configuração de exemplo
rm -f /etc/chrony/chrony.conf
# Instalar Chrony
apt install -y chrony
# Adicionar a configuração para sincronizar com servidores ntp.br
echo "server ntp.br iburst" | sudo tee /etc/chrony/chrony.conf
# Reiniciar o serviço Chrony
sudo systemctl restart chrony
# Habilitar o serviço Chrony
sudo systemctl enable chrony
# Verificar o status da sincronização
chronyc sources

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
sudo apt install docker-compose

## Aguardar o Docker subir
sleep 10
