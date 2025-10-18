#!/bin/bash

# Define diretório de trabalho
WORKDIR="/home/vagrant/laboratorios/lab-vuln/docker-vuln-NodeGoat"

# Clona o repositório se ainda não existir
cd "$WORKDIR"
if [ ! -d "$WORKDIR/NodeGoat" ]; then
  git clone https://github.com/OWASP/NodeGoat.git
fi

# Entra no diretório do projeto
cd NodeGoat

# 1) Remover a linha 1 (version)
sed -i '1d' docker-compose.yml

# 2) Remover a linha 2 (linha em branco)
sed -i '1d' docker-compose.yml

# 3) Adicionar restart e container_name em "web"
sed -i '/command:/a \    restart: unless-stopped\n    container_name: nodegoat-app' docker-compose.yml

# 4) Adicionar restart e container_name em "mongo"
sed -i '/image:/a \    restart: unless-stopped\n    container_name: mongodb-nodegoat' docker-compose.yml

# Constrói os containers
docker compose build

# Up Container
docker compose up -d
