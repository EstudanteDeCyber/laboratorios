#!/bin/bash

cd /home/vagrant/lab-sec/docker-vuln-Pixi

git clone https://github.com/DevSlop/Pixi

cd Pixi

# 1) Adicionar restart e container_name em "db-Pixi"
sed -i '/db:/a \    restart: unless-stopped\n    container_name: db-Pixi' docker-compose.yaml

# 2) Adicionar restart e container_name em "app-Pixi"
sed -i '/app:/a \    restart: unless-stopped\n    container_name: app-Pixi' docker-compose.yaml

docker compose up -d
