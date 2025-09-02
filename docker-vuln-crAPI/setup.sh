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
sed -i '/crapi-identity:/a \    restart: unless-stopped' docker-compose.yml

# 2) Adicionar restart e container_name em "crapi-community"
sed -i '/crapi-community:/a \    restart: unless-stopped' docker-compose.yml

# 3) Adicionar restart e container_name em "crapi-workshop"
sed -i '/crapi-workshop:/a \    restart: unless-stopped' docker-compose.yml

# 4) Adicionar restart e container_name em "crapi-web"
sed -i '/crapi-web:/a \    restart: unless-stopped' docker-compose.yml

# 5) Adicionar restart e container_name em "postgresdb"
sed -i '/postgresdb:/a \    restart: unless-stopped\n    container_name: crapi-postgresdb' docker-compose.yml

# 6) Adicionar restart e container_name em "mongo"
sed -i '/mongo:/a \    restart: unless-stopped\n    container_name: crapi-mongodb' docker-compose.yml

# 7) Adicionar restart e container_name em "mailhog"
sed -i '/mailhog:/a \    restart: unless-stopped' docker-compose.yml

# 8) Adicionar restart e container_name em "api.mypremiumdealership.com"
sed -i '/api\.mypremiumdealership\.com:/a \    restart: unless-stopped' docker-compose.yml

sed -i '213d' docker-compose.yml

sed -i '237' docker-compose.yml

# Baixa as imagens necessárias
docker compose pull

# Sobe os containers em segundo plano com compatibilidade
docker compose -f docker-compose.yml --compatibility up -d

# Garante que o serviço escute em todas as interfaces
LISTEN_IP="0.0.0.0" docker compose -f docker-compose.yml --compatibility up -d
