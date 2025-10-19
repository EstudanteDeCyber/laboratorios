#!/bin/bash

cd /home/vagrant/laboratorios/lab-vuln/docker-vuln-Pixi

git clone https://github.com/DevSlop/Pixi

cd Pixi

# 1) Deletar linas 1 e 2 
sed -i '1d' docker-compose.yaml
sed -i '1d' docker-compose.yaml

# 2) Adicionar restart e e renomear container_name para "Pixi-db" 
sed -i '/image:/a \    restart: unless-stopped' docker-compose.yaml
sed -i 's/pixidb/Pixi-db/g' docker-compose.yaml

# 3) Adicionar restart e container_name em "Pixi-app"
sed -i '/build/a \    restart: unless-stopped\n    container_name: Pixi-app' docker-compose.yaml

docker compose up -d
