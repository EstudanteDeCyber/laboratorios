#!/bin/bash

# Este script inicia todos os contêineres de laboratório de vulnerabilidades
# usando seus respectivos arquivos docker-compose.yml.

echo "Iniciando todos os laboratórios de vulnerabilidade..."

docker compose \
  -f ../docker-vuln-appsecco_dsvw/docker-compose.yml \
  -f ../docker-vuln-badstore/docker-compose.yml \
  -f ../docker-vuln-bWAPP/docker-compose.yml \
  -f ../docker-vuln-citizenstig_dvwa/docker-compose.yml \
  -f ../docker-vuln-citizenstig_nowasp/docker-compose.yml \
  -f ../docker-vuln-hackazon/docker-compose.yml \
  -f ../docker-vuln-juice-shop/docker-compose.yml \
  -f ../docker-vuln-vulnlab/docker-compose.yml \
  -f ../docker-vuln-webgoat/docker-compose.yml \
  -f ../docker-vuln-WrongSecrets/docker-compose.yml \
  -f ../docker-vuln-zap-webswing/docker-compose.yml \
  up -d

echo "Processo de inicialização concluído. Verifique o status com 'docker ps'."
