#!/bin/bash

cd /home/vagran/lab-sec/docker-vuln-flask2

git clone https://github.com/Lucas-Vini/vul-flask

cd vul-flask 

# 1) Adicionar restart e container_name em "crapi-identity"
sed -i '/web:/a \    restart: unless-stopped\n    container_name: vuln-flask2-web' compose.yaml

# 2) Adicionar restart e container_name em "crapi-community"
sed -i '/db:/a \    restart: unless-stopped\n    container_name: vuln-flask2-db' compose.yaml

# Altera a architerura da imagem do container
sed -i 's/arm/amd/g' compose.yaml

docker-compose up -d
