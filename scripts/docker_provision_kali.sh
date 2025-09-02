#!/bin/bash

# Este script automatiza o provisionamento do Docker e outras ferramentas
# essenciais em um ambiente Kali Linux.

## Ajuste do fuso horário
echo "Ajustando fuso horário..."
sudo timedatectl set-timezone America/Sao_Paulo

## Instalar PRÉ-REQUISITOS
echo "Instalando pacotes pré-requisitos..."
sudo apt install -y htop unzip curl ca-certificates apt-transport-https lsb-release gnupg jq

## Adicionando a instalação e configuração do Chrony
echo "Instalando e configurando Chrony para sincronizar com ntp.br..."
# Parar o serviço padrão de sincronização de tempo para evitar conflito
sudo timedatectl set-ntp false
# Remover o arquivo de configuração de exemplo
sudo rm -f /etc/chrony/chrony.conf
# Instalar Chrony
sudo apt install -y chrony
# Adicionar a configuração para sincronizar com servidores ntp.br
sudo echo "server ntp.br iburst" | tee /etc/chrony/chrony.conf
# Reiniciar o serviço Chrony
sudo systemctl restart chrony
# Habilitar o serviço Chrony
sudo systemctl enable chrony
# Verificar o status da sincronização
chronyc sources

## Instalação do Docker seguindo o procedimento oficial do Kali
echo "Instalando o Docker"
sudo apt install -y docker.io
sudo systemctl enable docker --now && sudo systemctl start docker --now
sudo usermod -aG docker vagrant
