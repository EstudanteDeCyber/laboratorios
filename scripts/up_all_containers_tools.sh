#!/bin/bash

# Este script inicia diversas ferramentas de segurança e infraestrutura
# usando seus respectivos arquivos docker-compose.yml.

echo "Iniciando as ferramentas de segurança..."

docker compose \
  -f ../lab-tools/docker-tools-waf2py/docker-compose.yml \
  -f ../lab-tools/docker-tools-hashicorp_vault/docker-compose.yml \
  -f ../lab-tools/docker-tools-nessus-essentials/docker-compose.yml \
  -f ../lab-tools/docker-tools-gophish/docker-compose.yml \
  -f ../lab-tools/docker-tools-inbucket/docker-compose.yml \
  -f ../lab-tools/docker-tools-openvas/docker-compose.yml \
  -f ../lab-tools/docker-tools-splunk/docker-compose.yml \
  up -d

echo "Processo de inicialização das ferramentas concluído. Verifique o status com 'docker ps'."
