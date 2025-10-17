#!/usr/bin/env bash
# provisioning/elk-setup.sh
# Provisiona uma stack ELK (Elasticsearch + Logstash + Kibana) usando Docker Compose
# Destinado a um lab – NÃO usar em produção sem ajustes de segurança.
#
# Requisitos:
# - Ubuntu 22.04 LTS (Jammy Jellyfish)
# - Usuário com sudo
set -euo pipefail

# Variáveis (ajuste conforme necessário)
ES_HEAP="1g"                  # heap do Elasticsearch (ajuste conforme RAM disponível)
ELASTIC_PASSWORD="changeme"   # senha inicial para o usuário elastic (lab)
BEATS_PORT=5044               # porta para Filebeat/Beats

echo "==> Instalando dependências (docker, docker-compose, curl, jq)..."
# instalar docker
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
  sudo usermod -aG docker "$USER" || true
fi

# docker-compose (v1 compatible via pip or binary)
if ! command -v docker-compose >/dev/null 2>&1; then
  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" \
       -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi

# criar diretórios para docker-compose e configs
WORKDIR="/opt/elk"
sudo mkdir -p "${WORKDIR}/logstash/pipeline" "${WORKDIR}/elasticsearch" "${WORKDIR}/kibana" "${WORKDIR}/certs"
sudo chown -R "$USER":"$USER" "${WORKDIR}"

cd "${WORKDIR}"

echo "==> Gerando docker-compose.yml..."
cat > docker-compose.yml <<'EOF'
version: '3.7'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.10.2
    environment:
      - node.name=es01
      - cluster.name=es-docker-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms${ES_HEAP} -Xmx${ES_HEAP}"
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - ./elasticsearch/data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
    networks:
      - elknet

  kibana:
    image: docker.elastic.co/kibana/kibana:7.10.2
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=${ELASTIC_PASSWORD}
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
    networks:
      - elknet

  logstash:
    image: docker.elastic.co/logstash/logstash:7.10.2
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
    ports:
      - "5044:5044"   # beats input
    depends_on:
      - elasticsearch
    networks:
      - elknet

networks:
  elknet:
    driver: bridge
EOF

echo "==> Gerando pipeline Logstash (beats -> Elasticsearch)..."
cat > logstash/pipeline/beats.conf <<'EOF'
input {
  beats {
    port => 5044
    # Se desejar TLS, habilite aqui e forneça certificados.
  }
}

filter {
  # filtros úteis (ajuste conforme necessidade)
  if [fileset][module] {
    # exemplo de processamento para módulos Filebeat
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    user => "elastic"
    password => "${ELASTIC_PASSWORD}"
    index => "%{[@metadata][beat]}-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
EOF

echo "==> Definindo variáveis de ambiente para docker-compose..."
cat > .env <<EOF
ES_HEAP=${ES_HEAP}
ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
EOF

echo "==> Ajustando permissões..."
mkdir -p elasticsearch/data
sudo chown -R 1000:1000 elasticsearch/data || true

echo "==> Iniciando containers (detached)..."
docker-compose up -d

echo "==> Esperando Elasticsearch inicializar (pode demorar alguns segundos)..."
# aguarda até que ES responda
for i in {1..30}; do
  if curl -s -u elastic:${ELASTIC_PASSWORD} http://localhost:9200/ >/dev/null 2>&1; then
    echo "Elasticsearch pronto."
    break
  fi
  echo "Aguardando... (${i})"
  sleep 3
done

# ===============================================================
# SSH Config
# ===============================================================
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^PubkeyAuthentication yes/#PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
echo "vagrant:vagrant" | chpasswd

# ===============================================================
# Ajustar Placa de REDE para o IP específico
# ===============================================================
cp /etc/network/interfaces /etc/network/interfaces.bak || true
cat << 'EONET' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
address 20.20.20.10
netmask 255.255.255.0
gateway 20.20.20.1
EONET

echo "==> ELK iniciado. Kibana em http://<IP_DA_VM>:5601"
echo "Usuário: elastic / Senha: ${ELASTIC_PASSWORD}"
echo "Logstash ouvindo na porta ${BEATS_PORT} (Beats). Ajuste seus Filebeat na T-Pot para enviar para essa porta."
echo "Fim do provisioning ELK."
