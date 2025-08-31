#!/bin/bash

# Este script automatiza o provisionamento do Docker e outras ferramentas
# essenciais em um ambiente Kali Linux.

## Ajuste do fuso horário
echo "Ajustando fuso horário..."
timedatectl set-timezone America/Sao_Paulo

## Update da máquina virtual
echo "Atualizando o sistema..."
apt update && apt-mark hold openssh-server
NEEDRESTART_MODE=a apt -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" upgrade

## Verificando e removendo instalações antigas do Docker
echo "Verificando e removendo instalações antigas do Docker, caso existam..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  apt-get remove -y $pkg || true
done

## Instalar PRÉ-REQUISITOS
echo "Instalando pacotes pré-requisitos..."
apt install -y htop unzip curl git ca-certificates apt-transport-https lsb-release gnupg jq

## Adicionando a instalação e configuração do Chrony
echo "Instalando e configurando Chrony para sincronizar com ntp.br..."
# Parar o serviço padrão de sincronização de tempo para evitar conflito
timedatectl set-ntp false
# Remover o arquivo de configuração de exemplo
rm -f /etc/chrony/chrony.conf
# Instalar Chrony
apt install -y chrony
# Adicionar a configuração para sincronizar com servidores ntp.br
echo "server ntp.br iburst" | tee /etc/chrony/chrony.conf
# Reiniciar o serviço Chrony
systemctl restart chrony
# Habilitar o serviço Chrony
systemctl enable chrony
# Verificar o status da sincronização
chronyc sources

## Instalação do Docker seguindo o procedimento oficial do Kali
sudo apt install -y docker.io
sudo systemctl enable docker --now && sudo systemctl start docker --now
sudo usermod -aG docker vagrant

# Adicionar o repositório do Docker à lista de fontes do APT
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
curl -fsSL https://download.docker.com/linux/debian/gpg |
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Instalar Docker Engine, CLI, Containerd e Docker Compose
echo "Executando a instalação do Docker Engine e Docker Compose..."
apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io

## Aguardar o Docker subir
echo "Aguardando o serviço Docker ficar pronto..."
sleep 10

echo "Instalação do Docker concluída!"
