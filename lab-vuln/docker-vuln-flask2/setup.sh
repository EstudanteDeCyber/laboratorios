#!/bin/bash

cd /home/vagran/lab-sec/docker-vuln-flask2

git clone https://github.com/Lucas-Vini/vul-flask

cd vul-flask 

# 1) Adicionar restart e container_name em "crapi-identity"
sed -i '/build/a \    restart: unless-stopped\n    container_name: vuln-flask2-web' compose.yaml

# 2) Adicionar restart e container_name em "crapi-community"
sed -i '/image:/a \    restart: unless-stopped\n    container_name: vuln-flask2-db' compose.yaml

# Altera a architerura da imagem do container
sed -i 's/arm/amd/g' compose.yaml

# Ajustes de portas:
sed -i 's/5000/5050/g' compose.yaml
sed -i 's/3306/3336/g' compose.yaml
sed -i 's/:3336/:3306/g' compose.yaml
sed -i 's/5000/5050/g' Dockerfile
sed -i 's/CMD \["flask", "run", "--debug"\]/CMD \["flask", "run", "--debug", "--host=0.0.0.0", "--port=5050"\]/g' Dockerfile

docker compose up -d
