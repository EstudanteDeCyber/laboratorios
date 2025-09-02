#!/bin/bash

# Diretório de trabalho
WORKDIR="/home/vagrant/lab-sec/docker-vuln-crAPI"

# Vai para o diretório de trabalho
cd "$WORKDIR"

# Baixa o arquivo ZIP do projeto, se ainda não estiver presente
if [ ! -f "$WORKDIR/main.zip" ]; then
  wget https://github.com/OWASP/crAPI/archive/refs/heads/main.zip
fi

# Descompacta se o diretório ainda não existir
if [ ! -d "$WORKDIR/crAPI-main" ]; then
  unzip main.zip
fi

# Entra no diretório de deployment do Docker
cd crAPI-main/deploy/docker

# 1) Adicionar restart e container_name em "crapi-identity"
sed -i '/image:/a \    restart: unless-stopped' docker-compose.yml

# Baixa as imagens necessárias
docker compose pull

# Sobe os containers em segundo plano com compatibilidade
#docker compose -f docker-compose.yml --compatibility up -d

# Garante que o serviço escute em todas as interfaces
#LISTEN_IP="0.0.0.0" docker compose -f docker-compose.yml --compatibility up -d
