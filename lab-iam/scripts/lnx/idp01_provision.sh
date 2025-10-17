#!/bin/bash
set -e

# ===============================================================
# Instalação docker e configuração do Inbucket
# ===============================================================

mkdir inbucket
cd inbucket
wget https://raw.githubusercontent.com/EstudanteDeCyber/lab-sec/main/docker-tools-inbucket/docker-compose.yml
wget https://raw.githubusercontent.com/EstudanteDeCyber/lab-sec/main/scripts/docker_provision.sh
chmod u+x docker_provision.sh
sudo bash docker_provision.sh
docker compose up -d

# ===============================================================
# Instalação KEYCLOAK
# ===============================================================

KEYCLOAK_VERSION="23.0.7"
KEYCLOAK_DIR="/opt/keycloak"

echo "[INFO] Atualizando sistema..."
apt update && apt upgrade -y

echo "[INFO] Instalando dependências essenciais..."
apt install -y openjdk-17-jdk wget tar postgresql postgresql-contrib nginx

echo "[INFO] Configurando banco de dados PostgreSQL..."
sudo -u postgres psql -c "CREATE ROLE keycloak WITH LOGIN PASSWORD 'keycloak';" || true
sudo -u postgres psql -c "CREATE DATABASE keycloak OWNER keycloak;" || true

echo "[INFO] Baixando Keycloak $KEYCLOAK_VERSION..."
wget https://github.com/keycloak/keycloak/releases/download/$KEYCLOAK_VERSION/keycloak-$KEYCLOAK_VERSION.tar.gz -O /tmp/keycloak.tar.gz

echo "[INFO] Extraindo Keycloak..."
mkdir -p $KEYCLOAK_DIR
tar -xzf /tmp/keycloak.tar.gz --strip-components=1 -C $KEYCLOAK_DIR

echo "[INFO] Definindo variáveis de ambiente para usuário admin..."
export KEYCLOAK_ADMIN=admin
export KEYCLOAK_ADMIN_PASSWORD=admin

echo "[INFO] Construindo Keycloak..."
cd $KEYCLOAK_DIR
$KEYCLOAK_DIR/bin/kc.sh build

echo "[INFO] Criando usuário systemd 'keycloak'..."
useradd -r -s /sbin/nologin keycloak || true
chown -R keycloak:keycloak $KEYCLOAK_DIR

echo "[INFO] Configurando serviço systemd para Keycloak..."
cat <<EOF >/etc/systemd/system/keycloak.service
[Unit]
Description=Keycloak Server
After=network.target

[Service]
Type=simple
User=keycloak
Group=keycloak
WorkingDirectory=$KEYCLOAK_DIR
Environment=JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
Environment=KEYCLOAK_ADMIN=admin
Environment=KEYCLOAK_ADMIN_PASSWORD=admin
ExecStart=$KEYCLOAK_DIR/bin/kc.sh start-dev
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "[INFO] Recarregando systemd e habilitando serviço Keycloak..."
systemctl daemon-reload
systemctl enable --now keycloak

echo "[INFO] Configurando Nginx como proxy reverso para Keycloak..."

# Criar config de redirecionamento para Keycloak
cat <<EOF >/etc/nginx/sites-available/keycloak.conf
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Remover site padrão do nginx
rm -f /etc/nginx/sites-enabled/default

# Habilitar config do Keycloak
ln -sf /etc/nginx/sites-available/keycloak.conf /etc/nginx/sites-enabled/keycloak.conf

# Testar e recarregar nginx
nginx -t && systemctl reload nginx

# ===============================================================
# Ajustar Placa de REDE para o IP específico
# ===============================================================
cp /etc/network/interfaces /etc/network/interfaces.bak || true
cat << 'EONET' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
address 10.10.10.30
netmask 255.255.255.0
EONET

# Backup do arquivo sshd_config original
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

echo "[INFO] Ajustando SSH para permitir login por senha..."

# Atualizar sshd_config para permitir senha
sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^UsePAM no/UsePAM yes/' /etc/ssh/sshd_config

# Garantir que PubkeyAuthentication não bloqueie o login por senha
sed -i 's/^PubkeyAuthentication yes/#PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Reiniciar o serviço sshd para aplicar alterações
systemctl restart sshd

# Resetar senha do usuário vagrant para 'vagrant' (ajuste a senha se quiser)
echo "vagrant:vagrant" | chpasswd

echo "[INFO] SSH ajustado para login por senha com usuário 'vagrant'."

echo "[INFO] Provisionamento concluído com sucesso!"