#!/bin/bash

# Define diretório de trabalho
WORKDIR="/home/vagrant/docker-vuln-NodeGoat"

# Clona o repositório se ainda não existir
cd "$WORKDIR"
if [ ! -d "$WORKDIR/NodeGoat" ]; then
  git clone https://github.com/OWASP/NodeGoat.git
fi

# Entra no diretório do projeto
cd NodeGoat

# Constrói os containers
docker-compose build
