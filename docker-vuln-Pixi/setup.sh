#!/bin/bash

cd /home/vagrant/lab-sec/docker-vuln-Pixi

git clone https://github.com/DevSlop/Pixi

cd Pixi

# 1) Deletar linas 1 e 2 
sed -i '1d' docker-compose.yaml
sed -i '1d' docker-compose.yaml

# 2) Adicionar restart e e renomear container_name para "db-Pixi" 
sed -i '/image:/a \    restart: unless-stopped' docker-compose.yaml
sed -i 's/pixidb/db-Pixi/g' docker-compose.yaml

# 3) Adicionar restart e container_name em "app-Pixi"
sed -i '/build/a \    restart: unless-stopped\n    container_name: app-Pixi' docker-compose.yaml

docker compose up -d
