#!/bin/bash

set -e

APP01_DIR="/var/www/app01"
APP02_DIR="/var/www/app02"
APP03_DIR="/var/www/app03"
VENV_DIR="$APP_DIR/venv"
SERVICE_FILE1="/etc/systemd/system/app01.service"
SERVICE_FILE2="/etc/systemd/system/app02.service"
SERVICE_FILE3="/etc/systemd/system/app03.service"
NGINX_CONF="/etc/nginx/sites-available/apps"
NGINX_LINK="/etc/nginx/sites-enabled/apps"

echo "[INFO] Atualizando pacotes..."
apt-get update -y && apt-get upgrade -y

echo "[INFO] Instalando dependências básicas..."
apt-get install -y python3 python3-venv python3-dev build-essential nginx

echo "[INFO] Criando diretório do app se não existir..."
mkdir -p "$APP01_DIR" "$APP02_DIR" "$APP03_DIR"
mkdir -p "$APP01_DIR/templates"

echo "[INFO] Criando ambiente virtual se não existir..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi

echo "[INFO] Instalando dependências Python no venv..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install flask gunicorn python-keycloak

echo "[INFO] Criando app01.py com suporte para configuração via variáveis de ambiente..."

cat > "$APP01_DIR/app01.py" << 'APP1'
import os
from flask import Flask, jsonify, render_template, request

app = Flask(__name__)

# Variáveis de ambiente para Keycloak
KEYCLOAK_SERVER_URL = os.getenv('KEYCLOAK_SERVER_URL')
KEYCLOAK_REALM = os.getenv('KEYCLOAK_REALM')
KEYCLOAK_CLIENT_ID = os.getenv('KEYCLOAK_CLIENT_ID')
KEYCLOAK_CLIENT_SECRET = os.getenv('KEYCLOAK_CLIENT_SECRET')

USE_KEYCLOAK = all([KEYCLOAK_SERVER_URL, KEYCLOAK_REALM, KEYCLOAK_CLIENT_ID, KEYCLOAK_CLIENT_SECRET])

if USE_KEYCLOAK:
    from keycloak import KeycloakOpenID
    keycloak_openid = KeycloakOpenID(
        server_url=KEYCLOAK_SERVER_URL,
        realm_name=KEYCLOAK_REALM,
        client_id=KEYCLOAK_CLIENT_ID,
        client_secret_key=KEYCLOAK_CLIENT_SECRET,
        verify=True  # SSL verify, ajustar se precisar
    )
else:
    keycloak_openid = None

@app.route('/')
def index():
    return render_template('index.html', keycloak_enabled=USE_KEYCLOAK)

@app.route('/check_auth', methods=['POST'])
def check_auth():
    if not USE_KEYCLOAK:
        return jsonify({"message": "Erro de autenticação"}), 401
    else:
        # Aqui você pode colocar uma lógica real de verificação da autenticação Keycloak
        # Para o exercício, só retornamos sucesso mesmo.
        return jsonify({"message": "App autenticado com sucesso."})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
APP1

echo "[INFO] Criando template HTML com botão para autenticação..."

cat > "$APP01_DIR/templates/index.html" << 'APP1'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <title>App com Keycloak</title>
  <script>
    async function checkAuth() {
      const response = await fetch('/check_auth', { method: 'POST' });
      const data = await response.json();
      alert(data.message);
    }
  </script>
</head>
<body>
  <h1>Minha Aplicação 01</h1>
  <button onclick="checkAuth()">Verificar Autenticação</button>
  <p>Status do Keycloak: {{ 'Ativado' if keycloak_enabled else 'Desativado' }}</p>
</body>
</html>
APP1

cat > "$APP01_DIR/app02.py" << 'APP2'
import os
from flask import Flask, redirect, request, session, url_for, render_template_string
import requests
from urllib.parse import urlencode

app = Flask(__name__)
app.secret_key = "supersecret"  # Troque em produção

KEYCLOAK_URL = os.getenv("KEYCLOAK_SERVER_URL")
REALM = os.getenv("KEYCLOAK_REALM")
CLIENT_ID = os.getenv("KEYCLOAK_CLIENT_ID")
CLIENT_SECRET = os.getenv("KEYCLOAK_CLIENT_SECRET")
REDIRECT_URI = os.getenv("REDIRECT_URI")

LOGIN_TEMPLATE = """
<h2>App02 - Login via Keycloak</h2>
{% if user %}
    <p>Bem-vindo, {{ user['preferred_username'] }}!</p>
    <p><a href="/logout">Sair</a></p>
{% else %}
    <a href="/login">Entrar com Keycloak</a>
{% endif %}
"""

@app.route("/")
def index():
    return render_template_string(LOGIN_TEMPLATE, user=session.get("user"))

@app.route("/login")
def login():
    params = {
        "client_id": CLIENT_ID,
        "response_type": "code",
        "scope": "openid profile email",
        "redirect_uri": REDIRECT_URI
    }
    url = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/auth?{urlencode(params)}"
    return redirect(url)

@app.route("/callback")
def callback():
    code = request.args.get("code")
    token_url = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/token"
    data = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": REDIRECT_URI,
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET
    }
    token = requests.post(token_url, data=data).json()
    userinfo_url = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/userinfo"
    userinfo = requests.get(userinfo_url, headers={"Authorization": f"Bearer {token['access_token']}"}).json()
    session["user"] = userinfo
    return redirect(url_for("index"))

@app.route("/logout")
def logout():
    session.clear()
    return redirect("/")
    
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002, debug=True)
APP2

echo "[INFO] Criando serviços systemd..."

cat > "$SERVICE_FILE1" << APP1
[Unit]
Description=Gunicorn instance to serve app01
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$APP01_DIR
Environment="PATH=$VENV_DIR/bin"
Environment="KEYCLOAK_SERVER_URL=${KEYCLOAK_SERVER_URL:-}"
Environment="KEYCLOAK_REALM=${KEYCLOAK_REALM:-}"
Environment="KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-}"
Environment="KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-}"
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind 0.0.0.0:5001 app:app

[Install]
WantedBy=multi-user.target
APP1

cat > "$SERVICE_FILE2" << APP2
[Unit]
Description=Gunicorn instance to serve app02
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$APP02_DIR
Environment="PATH=$VENV_DIR/bin"
Environment="KEYCLOAK_SERVER_URL=${KEYCLOAK_SERVER_URL:-}"
Environment="KEYCLOAK_REALM=${KEYCLOAK_REALM:-}"
Environment="KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-}"
Environment="KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-}"
Environment="REDIRECT_URI=${REDIRECT_URI:-}"
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind 0.0.0.0:5002 app02:app

[Install]
WantedBy=multi-user.target
APP2

cat > "$SERVICE_FILE3" << APP3
[Unit]
Description=Gunicorn instance to serve app03
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$APP02_DIR
Environment="PATH=$VENV_DIR/bin"
Environment="KEYCLOAK_SERVER_URL=${KEYCLOAK_SERVER_URL:-}"
Environment="KEYCLOAK_REALM=${KEYCLOAK_REALM:-}"
Environment="KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-}"
Environment="KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-}"
Environment="REDIRECT_URI=${REDIRECT_URI:-}"
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind 0.0.0.0:5003 app03:app

[Install]
WantedBy=multi-user.target
APP3

echo "[INFO] Habilitando e iniciando serviço systemd..."
systemctl daemon-reload
systemctl enable pp01.service app02.service app03.service
systemctl restart app01.service app02.service app03.service

echo "[INFO] Criando configuração do Nginx..."

cat > "$NGINX_CONF" << EOF
server {
    listen 81;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
server {
    listen 82;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5002;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
server {
    listen 83;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5003;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

if [ ! -L "$NGINX_LINK" ]; then
    ln -s "$NGINX_CONF" "$NGINX_LINK"
fi

echo "[INFO] Testando configuração do Nginx e recarregando..."
nginx -t && systemctl reload nginx

# Testar e recarregar nginx
nginx -t && systemctl reload nginx

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
echo "Aplicação 01 em 0.0.0.0:5001 e proxy reverso pelo Nginx na porta 81."
echo "Aplicação 02 em 0.0.0.0:5002 e proxy reverso pelo Nginx na porta 82."
echo "Aplicação 03 em 0.0.0.0:5003 e proxy reverso pelo Nginx na porta 82."
echo "Para ativar Keycloak, defina as variáveis de ambiente no arquivo de serviço systemd e reinicie o serviço:"
echo "  KEYCLOAK_SERVER_URL, KEYCLOAK_REALM, KEYCLOAK_CLIENT_ID, KEYCLOAK_CLIENT_SECRET"
