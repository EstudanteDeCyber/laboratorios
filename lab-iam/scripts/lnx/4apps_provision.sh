set -euo pipefail
Provision script: App01 (existing) + App02 + App03 (Todo List)
Pads: /var/www/app01, /var/www/app02, /var/www/app03
Uses: www-data, venv por app, gunicorn, systemd services, nginx reverse proxy

set -e
---------- Configuracoes (ajuste se necessario) ----------

APP01_DIR="/var/www/app01"
APP02_DIR="/var/www/app02"
APP03_DIR="/var/www/app03"
APP04_DIR="/var/www/app04"

PYTHON_BIN="/usr/bin/python3"

SERVICE_FILE1="/etc/systemd/system/app01.service"
SERVICE_FILE2="/etc/systemd/system/app02.service"
SERVICE_FILE3="/etc/systemd/system/app03.service"
SERVICE_FILE4="/etc/systemd/system/app04.service"

NGINX_CONF="/etc/nginx/sites-available/apps"
NGINX_LINK="/etc/nginx/sites-enabled/apps"

echo "vagrant:vagrant" | chpasswd

echo "[INFO] SSH ajustado para login por senha com usuario 'vagrant'."

GUNICORN_WORKERS=3

export KEYCLOAK_SERVER_URL="http://10.10.10.30"
export KEYCLOAK_REALM="myrealm"

---------- Pacotes base ----------

echo "[INFO] Atualizando pacotes e instalando dependencias base..."
apt-get update -y && apt-get upgrade -y
apt-get install -y python3 python3-venv python3-dev build-essential nginx git curl

id -u www-data >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin www-data

---------- Funcao utilitaria para criar app (venv, estruturas) ----------

create_app_structure() {
local APP_DIR="$1"
local APP_NAME="$2"

echo "[INFO] Criando estrutura para $APP_NAME em ${APP_DIR}..."
mkdir -p "${APP_DIR}"
chown -R www-data:www-data "${APP_DIR}"
chmod 755 "${APP_DIR}"

$PYTHON_BIN -m venv "${APP_DIR}/venv"

"${APP_DIR}/venv/bin/python" -m pip install --upgrade pip >/dev/null
}

---------- Criar diretorios e venvs ----------

create_app_structure "$APP01_DIR" "app01"
create_app_structure "$APP02_DIR" "app02"
create_app_structure "$APP03_DIR" "app03"
create_app_structure "$APP04_DIR" "app04"

# Os blocos de codigo de cada app devem ser adaptados separadamente conforme o trecho que voce colou.

---------- Systemd unit files (padrao consistente) ----------

cat > "${SERVICE_FILE1}" <<EOF
[Unit]
Description=Gunicorn instance to serve app01
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=${APP01_DIR}
Environment="PATH=${APP01_DIR}/venv/bin"
Environment="KEYCLOAK_SERVER_URL=${KEYCLOAK_SERVER_URL:-}"
Environment="KEYCLOAK_REALM=${KEYCLOAK_REALM:-}"
Environment="KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-}"
Environment="KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-}"
Environment="REDIRECT_URI=${REDIRECT_URI:-}"
ExecStart=${APP01_DIR}/venv/bin/gunicorn --workers ${GUNICORN_WORKERS} --bind 0.0.0.0:5001 app:app

[Install]
WantedBy=multi-user.target
EOF

# (Repita o mesmo processo para os outros arquivos de service: app02, app03, app04)

systemctl daemon-reload
systemctl enable --now app01.service || true
systemctl enable --now app02.service || true
systemctl enable --now app03.service || true
systemctl enable --now app04.service || true

---------- Nginx config ----------

cat > "${NGINX_CONF}" <<'EOF'
upstream app01 { server 127.0.0.1:5001; }
upstream app02 { server 127.0.0.1:5002; }
upstream app03 { server 127.0.0.1:5003; }
upstream app04 { server 127.0.0.1:5004; }

server {
listen 80 default_server;
listen [::]:80 default_server;
server_name _;

location /app01/ {
    proxy_pass http://app01/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

location /app02/ {
    proxy_pass http://app02/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

location /app03/ {
    proxy_pass http://app03/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

location /app04/ {
    proxy_pass http://app04/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

location / {
    return 200 "Reverse proxy para app01/app02/app03/app04. Use /app01/, /app02/, /app03/ ou /app04/\\n";
}
}
EOF

ln -sf "${NGINX_CONF}" "${NGINX_LINK}"
nginx -t && systemctl reload nginx

---------- Permissoes ----------

chown -R www-data:www-data "$APP01_DIR" "$APP02_DIR" "$APP03_DIR" "$APP04_DIR"
chmod -R 750 "$APP01_DIR" "$APP02_DIR" "$APP03_DIR" "$APP04_DIR"

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

echo "[INFO] Ajustando SSH para permitir login por senha..."

sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^PubkeyAuthentication yes/#PubkeyAuthentication yes/' /etc/ssh/sshd_config

systemctl restart sshd

---------- Instrucoes finais ----------

echo "[INFO] Provisionamento finalizado."
echo "Apps implantados:"
echo "  - App01: ${APP01_DIR} (gunicorn -> 5001) proxy em /app01/"
echo "  - App02: ${APP02_DIR} (gunicorn -> 5002) proxy em /app02/"
echo "  - App03: ${APP03_DIR} (gunicorn -> 5003) proxy em /app03/"
echo "  - App04: ${APP04_DIR} (gunicorn -> 5004) proxy em /app04/"
echo
echo "ATENCAO: defina as variaveis do Keycloak antes de reiniciar (ou edite os arquivos systemd) para os apps's 2, 3, 4:"
echo "  KEYCLOAK_SERVER_URL (ex: http://10.10.10.30)"
echo "  KEYCLOAK_REALM (ex: myrealm)"
echo "  KEYCLOAK_CLIENT_ID (ex: app04)"
echo "  KEYCLOAK_CLIENT_SECRET (segredo do client)"
echo "  REDIRECT_URI (ex: http://<host>/app04/callback)"
echo
echo "[DONE]"