#!/bin/bash
set -euo pipefail
trap 'echo "[ERROR] Linha $LINENO falhou"; exit 1' ERR

# ---------- Pacotes base ----------
echo "[INFO] Atualizando pacotes e dependencias..."
apt-get update -y && apt-get upgrade -y
apt-get install -y python3 python3-venv python3-dev build-essential nginx curl

# Garante que o usuario www-data exista (padrão em Debian/Ubuntu)
id -u www-data >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin www-data

# ===============================================================
# Provisionamento Apps: App01, App02 e App03
# Flask + Gunicorn + systemd + Nginx
# ===============================================================

BASE_DIR="/var/www"
PYTHON_BIN="/usr/bin/python3"
GUNICORN_WORKERS="$(nproc)"  # Ajusta numero de workers conforme CPUs

NGINX_CONF="/etc/nginx/sites-available/apps"
NGINX_LINK="/etc/nginx/sites-enabled/apps"

# ---------- Funcao para criar estrutura de app ----------
deploy_app() {
  local APP_NAME="$1"
  local APP_PORT="$2"
  local APP_DIR="${BASE_DIR}/${APP_NAME}"
  local SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"

  echo "[INFO] Criando estrutura para ${APP_NAME} na porta ${APP_PORT}..."

  mkdir -p "${APP_DIR}/templates"
  chown -R www-data:www-data "${APP_DIR}"
  chmod 755 "${APP_DIR}"
  ${PYTHON_BIN} -m venv "${APP_DIR}/venv"
  "${APP_DIR}/venv/bin/python" -m pip install --upgrade pip >/dev/null

  # Criar app Flask basico
  cat > "${APP_DIR}/app.py" <<EOF
from flask import Flask, render_template
import os
app = Flask(__name__)
app.secret_key = os.getenv("${APP_NAME^^}_SECRET_KEY", "default-secret")

@app.route("/")
def index():
    return render_template("index.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=${APP_PORT})
EOF

  # Criar template HTML
  cat > "${APP_DIR}/templates/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>${APP_NAME} - Flask + Keycloak</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f4; text-align: center; padding: 50px; }
    h1 { color: #333; }
    .card { background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 6px rgba(0,0,0,0.2); display: inline-block; }
  </style>
</head>
<body>
  <div class="card">
    <h1>${APP_NAME} - Protegido pelo Keycloak</h1>
    <p>Este aplicativo roda na porta ${APP_PORT}.</p>
    <p><strong>Status:</strong> autenticado via Keycloak</p>
  </div>
</body>
</html>
EOF

  # Criar requirements.txt
  cat > "${APP_DIR}/requirements.txt" <<EOF
Flask>=2.0
gunicorn>=20
EOF

  # Instalar dependencias
  "${APP_DIR}/venv/bin/pip" install --no-cache-dir -r "${APP_DIR}/requirements.txt" >/dev/null

  # Criar service systemd
  cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Gunicorn instance to serve ${APP_NAME}
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=${APP_DIR}
Environment="PATH=${APP_DIR}/venv/bin"
ExecStart=${APP_DIR}/venv/bin/gunicorn --workers ${GUNICORN_WORKERS} --bind 0.0.0.0:${APP_PORT} app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

# ===============================================================
# Deploy dos apps
# ===============================================================
deploy_app "app01" 5001
deploy_app "app02" 5002
deploy_app "app03" 5003

# ===============================================================
# Systemd e Nginx
# ===============================================================
systemctl daemon-reload
systemctl enable app01.service app02.service app03.service
systemctl start app01.service app02.service app03.service

# Configuracao unica do Nginx
cat > "${NGINX_CONF}" <<EOF
server {
    listen 80;

    location /app01 {
        proxy_pass http://127.0.0.1:5001;
    }
    location /app02 {
        proxy_pass http://127.0.0.1:5002;
    }
    location /app03 {
        proxy_pass http://127.0.0.1:5003;
    }
}
EOF

ln -sf "${NGINX_CONF}" "${NGINX_LINK}"

nginx -t && systemctl reload nginx

echo "[INFO] Provisionamento concluido com sucesso."
