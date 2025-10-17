#!/usr/bin/env bash
# provisioning/stack-core_setup.sh
# Script de provisionamento simples para ELK-STACK, Shuffle e DFIR-IRIS
set -euo pipefail

# ===============================================================
# Instalacao do Shuffle
# ===============================================================
echo "# ==============================================================="
echo "# Instalacao do Shuffle"
echo "# ==============================================================="

cd /opt
git clone https://github.com/Shuffle/Shuffle
cd Shuffle
mkdir shuffle-database && sudo chown -R 1000:1000 shuffle-database
docker compose up -d

# ===============================================================
# Instalacao do DFIR-IRIS
# ===============================================================
echo "# ==============================================================="
echo "# Instalacao do DFIR-IRIS"
echo "# ==============================================================="

cd /opt
git clone https://github.com/dfir-iris/iris-web.git
cd iris-web
git checkout v2.4.11
cp .env.model .env
docker compose build
docker compose up -d

# ===============================================================
# Instalacao do ELK Stack
# ===============================================================
echo "# ==============================================================="
echo "# Instalacao do ELK Stack"
echo "# ==============================================================="

cd /opt
mkdir elk-stack
cd elk-stack

# Cria o arquivo docker-compose.yml
cat << 'ELKSTACK' > docker-compose.yml 
services:
  setup:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.1
    ports:
      - 9222:9222
    environment:
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
      - KIBANA_PASSWORD=${KIBANA_PASSWORD}
    container_name: setup
    command:
      - bash
      - -c
      - |
        echo "Waiting for Elasticsearch availability";
        until curl -s http://elasticsearch:9200 | grep -q "missing authentication credentials"; do sleep 30; done;
        echo "Setting kibana_system password";
        until curl -s -X POST -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" http://elasticsearch:9200/_security/user/kibana_system/_password -d "{\"password\":\"${KIBANA_PASSWORD}\"}" | grep -q "^{}"; do sleep 10; done;
        echo "All done!";

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.1
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - cluster.name=elasticsearch
      - bootstrap.memory_lock=true
      - ES_JAVA_OPTS=-Xms1g -Xmx1g
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
      - xpack.security.http.ssl.enabled=false

  kibana:
    image: docker.elastic.co/kibana/kibana:8.12.1
    container_name: kibana
    ports:
      - 5601:5601
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=kibana_system
      - ELASTICSEARCH_PASSWORD=${KIBANA_PASSWORD}
      - TELEMETRY_ENABLED=false

ELKSTACK

# Cria o arquivo .env com as senhas padrao
cat << 'ELKSTACK' > .env
ELASTIC_PASSWORD=senha@123
KIBANA_PASSWORD=senha@123
ELKSTACK

# Sobe os containers do ELK Stack
docker compose up -d

# ===============================================================
# Ajuste de rede - configura endereco IP fixo
# ===============================================================
echo "# ==============================================================="
echo "# Ajuste de rede - configurando IP fixo"
echo "# ==============================================================="

cp /etc/network/interfaces /etc/network/interfaces.bak || true

cat << 'EONET' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth1
iface eth0 inet static
address 10.10.10.200
netmask 255.255.255.0
EONET

# Adiciona entradas no /etc/hosts
cat << 'EONET' >> /etc/hosts
10.10.10.200 	stack-core
10.10.10.201	ai-node
EONET

# ===============================================================
# Informacoes de acesso aos servicos
# ===============================================================
echo "# ==============================================================="
echo "# Shuffle            -->> http://stack-core:3443"
echo "# Kibana             -->> http://stack-core:5601"
echo "# Elasticsearch      -->> http://stack-core:9222"
echo "# DFIR-IRIS          -->> http://stack-core:443"
echo "# ==============================================================="