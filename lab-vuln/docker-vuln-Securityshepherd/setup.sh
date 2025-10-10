#!/bin/bash

# Diretório de trabalho
WORKDIR="/home/vagrant/laboratorio/lab-vuln/docker-vuln-Securityshepherd"

# Atualiza os pacotes e instala as dependências
sudo apt update
sudo apt install -y maven openjdk-17-jre openjdk-17-jdk

# Entra no diretório de trabalho
cd "$WORKDIR"

# Clona o repositório se ainda não existir
if [ ! -d "$WORKDIR/SecurityShepherd" ]; then
  git clone https://github.com/OWASP/SecurityShepherd.git
fi

# Entra no diretório do projeto
cd SecurityShepherd

# 1) Remover a linha 1 (version)
sed -i '1d' docker-compose.yml

# 2) Adicionar restart e container_name em "db"
sed -i '/db:/a \    restart: unless-stopped' docker-compose.yml

# 3) Adicionar restart e container_name em "mongo"
sed -i '/mongo:/a \    restart: unless-stopped' docker-compose.yml

# 4) Adicionar restart e container_name em "web"
sed -i '/web:/a \    restart: unless-stopped' docker-compose.yml

# 1) Remover a linha 1 (version)
sed -i '53d' docker-compose.yml

# Compila o projeto usando Maven com o perfil docker e ignora os testes
sudo mvn -Pdocker clean install -DskipTests

# Up Container
docker compose up -d
