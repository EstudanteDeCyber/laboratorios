#!/bin/bash

cd /home/vagrant/laboratorios/lab-vuln//docker-vuln-bank

git clone https://github.com/Commando-X/vuln-bank.git

cd vuln-bank

#1) Deleção das linhas 1 e 2
sed -i '1d' docker-compose.yml
sed -i '1d' docker-compose.yml

# 2) Ajustes de portas
sed -i 's/5000:5000/5005:5005/g' docker-compose.yml
sed -i 's/80:5000/5080:5005/g' docker-compose.yml
sed -i 's/5432:5432/5433:5432/g' docker-compose.yml

# 3) Adicionar restart e container_name para "web-bank"
sed -i '/build/a \    restart: unless-stopped\n    container_name: bank-web' docker-compose.yml

# 4) Adicionar restart e container_name para "web-db"
sed -i '/image:/a \    restart: unless-stopped\n    container_name: bank-db' docker-compose.yml

# 5) Alterar porta exposta no Dockerfile
sed -i 's/EXPOSE\ 5000/EXPOSE\ 5005/g' Dockerfile

# 6) Alterar porta no app.py
sed -i 's/port=5000/port=5005/g' app.py

docker compose up -d
