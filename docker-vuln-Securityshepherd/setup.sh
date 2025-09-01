#!/bin/bash

# Diretório de trabalho
WORKDIR="/home/vagrant/docker-vuln-Securityshepherd"

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

# Compila o projeto usando Maven com o perfil docker e ignora os testes
sudo mvn -Pdocker clean install -DskipTests

# Up Container
docker compose up -d
