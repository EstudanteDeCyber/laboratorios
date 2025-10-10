#!/bin/bash
set -euo pipefail

## Ajuste timezone
timedatectl set-timezone America/Sao_Paulo

# ---------- Pacotes base ----------
echo "[INFO] Atualizando pacotes e instalando dependencias base..."
apt-get update -y && apt-get upgrade -y
apt-get install -y python3 python3-venv python3-dev build-essential nginx curl

# Ensure www-data user exists
id -u www-data >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin www-data

# ===============================================================
# Provisionamento Apps: App01, App02 e App03
# Flask + Gunicorn + systemd + Nginx
# ===============================================================

APP01_DIR="/var/www/app01"
APP02_DIR="/var/www/app02"
APP03_DIR="/var/www/app03"

SERVICE_FILE1="/etc/systemd/system/app01.service"
SERVICE_FILE2="/etc/systemd/system/app02.service"
SERVICE_FILE3="/etc/systemd/system/app03.service"

NGINX_CONF="/etc/nginx/sites-available/apps"
NGINX_LINK="/etc/nginx/sites-enabled/apps"

PYTHON_BIN="/usr/bin/python3"
GUNICORN_WORKERS=3

# ---------- Funcao utilitaria ----------
create_app_structure() {
  local APP_DIR="$1"
  mkdir -p "${APP_DIR}"
  mkdir -p "$APP01_DIR/templates"
  chown -R www-data:www-data "${APP_DIR}"
  chmod 755 "${APP_DIR}"
  ${PYTHON_BIN} -m venv "${APP_DIR}/venv"
  "${APP_DIR}/venv/bin/python" -m pip install --upgrade pip >/dev/null
}

# ===============================================================
# App01
# ===============================================================
create_app_structure "${APP01_DIR}"

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
        return jsonify({"message": "Configure a autenticação no Keycloak"}), 200
    else:
        # Aqui você pode colocar uma lógica real de verificação da autenticação Keycloak
        return jsonify({"message": "App autenticado no Keycloak"}), 200

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

cat > "${APP01_DIR}/requirements.txt" <<'EOF'
Flask>=2.0
gunicorn>=20
EOF

"${APP01_DIR}/venv/bin/pip" install -r "${APP01_DIR}/requirements.txt" >/dev/null

# ===============================================================
# App02
# ===============================================================
create_app_structure "${APP02_DIR}"

cat > "${APP02_DIR}/app.py" <<'EOF'
import os
from flask import Flask, redirect, request, session, url_for, render_template
import requests
from urllib.parse import urlencode

app = Flask(__name__)
app.secret_key = os.getenv("APP02_SECRET", "change_me")

KEYCLOAK_URL = os.getenv("KEYCLOAK_SERVER_URL")
REALM = os.getenv("KEYCLOAK_REALM")
CLIENT_ID = os.getenv("KEYCLOAK_CLIENT_ID")
CLIENT_SECRET = os.getenv("KEYCLOAK_CLIENT_SECRET")
REDIRECT_URI = os.getenv("REDIRECT_URI")

@app.route("/")
def index():
    return render_template("index.html", user=session.get("user"))

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
    kc_logout = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/logout"
    return redirect(kc_logout)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002, debug=True)
EOF

mkdir -p "${APP02_DIR}/templates"
cat > "${APP02_DIR}/templates/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>App02 - Login Delegado</title>
  <style>
    body { font-family: Arial, sans-serif; background: #eef7ff; text-align: center; padding: 50px; }
    h1 { color: #004080; }
    .card { background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 6px rgba(0,0,0,0.2); display: inline-block; }
  </style>
</head>
<body>
  <div class="card">
    <h1>App02 - Login Delegado com Keycloak</h1>
    {% if user %}
      <p><strong>Usuario:</strong> {{ user['preferred_username'] }}</p>
      <p><strong>Email:</strong> {{ user.get('email', 'nao informado') }}</p>
      <a href="/logout">Sair</a>
    {% else %}
      <p>Voce ainda nao esta autenticado.</p>
      <a href="/login">Entrar com Keycloak</a>
    {% endif %}
  </div>
</body>
</html>
EOF

cat > "${APP02_DIR}/requirements.txt" <<'EOF'
Flask>=2.0
requests>=2.20
gunicorn>=20
EOF

"${APP02_DIR}/venv/bin/pip" install -r "${APP02_DIR}/requirements.txt" >/dev/null

# ===============================================================
# App03
# ===============================================================
create_app_structure "${APP03_DIR}"

cat > "${APP03_DIR}/app03.py" <<'EOF'
import os
from flask import Flask, redirect, request, session, url_for, render_template, abort
from urllib.parse import urlencode
import requests

app = Flask(__name__)
app.secret_key = os.getenv("APP_SECRET", "change_this_in_prod")

KEYCLOAK_URL = os.getenv("KEYCLOAK_SERVER_URL")
REALM = os.getenv("KEYCLOAK_REALM")
CLIENT_ID = os.getenv("KEYCLOAK_CLIENT_ID")
CLIENT_SECRET = os.getenv("KEYCLOAK_CLIENT_SECRET")
REDIRECT_URI = os.getenv("REDIRECT_URI")

TODOS = {}

def get_roles_from_userinfo(userinfo):
    realm_access = userinfo.get("realm_access", {})
    return realm_access.get("roles", [])

@app.route("/")
def index():
    user = session.get("user")
    roles = get_roles_from_userinfo(user) if user else []
    username = user.get("preferred_username") if user else None
    todos = TODOS.get(username, []) if username else []
    return render_template("index.html", user=user, roles=roles, todos=todos)

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
    
@app.route("/add", methods=["POST"])
def add_todo():
    if "user" not in session: return redirect(url_for("login"))
    text = request.form.get("text")
    username = session["user"].get("preferred_username")
    TODOS.setdefault(username, []).append(text)
    return redirect(url_for("index"))

@app.route("/admin")
def admin():
    user = session.get("user")
    if not user: return redirect(url_for("login"))
    roles = get_roles_from_userinfo(user)
    if "admin" not in roles: abort(403)
    return "<h1>Area admin - restrita a role admin</h1>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5003, debug=True)
EOF

mkdir -p "${APP03_DIR}/templates"
cat > "${APP03_DIR}/templates/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>App03 - Todo List</title>
  <style>
    body { font-family: Arial, sans-serif; background: #fff8f0; text-align: center; padding: 50px; }
    h1 { color: #804000; }
    .card { background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 6px rgba(0,0,0,0.2); display: inline-block; text-align: left; }
    ul { text-align: left; }
  </style>
</head>
<body>
  <div class="card">
    <h1>App03 - Todo List com Roles</h1>
    {% if user %}
      <p><strong>Usuario:</strong> {{ user['preferred_username'] }}</p>
      <p><strong>Roles:</strong> {{ roles }}</p>
      <h3>Suas tarefas:</h3>
      <ul>
        {% for t in todos %}
          <li>{{ t }}</li>
        {% endfor %}
      </ul>
      <form method="post" action="/add">
        <input name="text" placeholder="Nova tarefa" required>
        <button type="submit">Adicionar</button>
      </form>
      <p><a href="/logout">Sair</a></p>
      {% if 'admin' in roles %}
        <p><a href="/admin">Ir para area Admin</a></p>
      {% endif %}
    {% else %}
      <p>Voce nao esta logado.</p>
      <a href="/login">Entrar com Keycloak</a>
    {% endif %}
  </div>
</body>
</html>
EOF

cat > "${APP03_DIR}/requirements.txt" <<'EOF'
Flask>=2.0
requests>=2.20
gunicorn>=20
EOF

"${APP03_DIR}/venv/bin/pip" install -r "${APP03_DIR}/requirements.txt" >/dev/null

# ===============================================================
# systemd Services
# ===============================================================
cat > "${SERVICE_FILE1}" <<EOF
[Unit]
Description=Gunicorn instance to serve app01
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=${APP01_DIR}
Environment="PATH=${APP01_DIR}/venv/bin"
ExecStart=${APP01_DIR}/venv/bin/gunicorn --workers ${GUNICORN_WORKERS} --bind 0.0.0.0:5001 app01:app

[Install]
WantedBy=multi-user.target
EOF

cat > "${SERVICE_FILE2}" <<EOF
[Unit]
Description=Gunicorn instance to serve app02
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=${APP02_DIR}
Environment="PATH=${APP02_DIR}/venv/bin"
Environment="KEYCLOAK_SERVER_URL=${KEYCLOAK_SERVER_URL:-}"
Environment="KEYCLOAK_REALM=${KEYCLOAK_REALM:-}"
Environment="KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-}"
Environment="KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-}"
Environment="REDIRECT_URI=${REDIRECT_URI:-}"
ExecStart=${APP02_DIR}/venv/bin/gunicorn --workers ${GUNICORN_WORKERS} --bind 0.0.0.0:5002 app02:app

[Install]
WantedBy=multi-user.target
EOF

cat > "${SERVICE_FILE3}" <<EOF
[Unit]
Description=Gunicorn instance to serve app03 (Todo List)
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=${APP03_DIR}
Environment="PATH=${APP03_DIR}/venv/bin"
Environment="KEYCLOAK_SERVER_URL=${KEYCLOAK_SERVER_URL:-}"
Environment="KEYCLOAK_REALM=${KEYCLOAK_REALM:-}"
Environment="KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-}"
Environment="KEYCLOAK_CLIENT_SECRET=${KEYCLOAK_CLIENT_SECRET:-}"
Environment="REDIRECT_URI=${REDIRECT_URI:-}"
Environment="APP_SECRET=${APP_SECRET:-}"
ExecStart=${APP03_DIR}/venv/bin/gunicorn --workers ${GUNICORN_WORKERS} --bind 0.0.0.0:5003 app03:app

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable app01 app02 app03
systemctl start app01

# Remover site default do Debian/Ubuntu para evitar conflito
if [ -f /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
fi

# ===============================================================
# Nginx reverse proxy
# ===============================================================
cat > "${NGINX_CONF}" <<'EOF'
upstream app01 { server 127.0.0.1:5001; }
upstream app02 { server 127.0.0.1:5002; }
upstream app03 { server 127.0.0.1:5003; }

server {
    listen 80 default_server;
    server_name _;

    # App01
    location /app01/ {
        rewrite ^/app01(/.*)$ $1 break;
        proxy_pass http://127.0.0.1:5001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # App02
    location /app02/ {
        rewrite ^/app02(/.*)$ $1 break;
        proxy_pass http://127.0.0.1:5002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # App03
    location /app03/ {
        rewrite ^/app03(/.*)$ $1 break;
        proxy_pass http://127.0.0.1:5003;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # App03
    location /app04/ {
        rewrite ^/app04(/.*)$ $1 break;
        proxy_pass http://127.0.0.1:5004;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    # Página principal
    location / {
        root /var/www/html;
        index index.html;
    }
}
EOF

ln -sf "${NGINX_CONF}" "${NGINX_LINK}"

# Dashboard inicial
mkdir -p /var/www/html
cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>Lab IAM - Dashboard</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f0f2f5; text-align: center; padding: 50px; }
    h1 { color: #222; }
    .grid { display: flex; justify-content: center; gap: 20px; margin-top: 40px; flex-wrap: wrap; }
    .card { background: white; border-radius: 10px; padding: 20px; width: 250px; box-shadow: 0 2px 6px rgba(0,0,0,0.2); transition: transform .2s; }
    .card:hover { transform: scale(1.05); }
    a { text-decoration: none; color: #004080; font-weight: bold; }
  </style>
</head>
<body>
  <h1>Lab IAM - Dashboard</h1>
  <p>Escolha um dos aplicativos para iniciar os testes:</p>
  <div class="grid">
    <div class="card">
      <h2>App01</h2>
      <p>App simples, protegido pelo Keycloak.</p>
      <a href="/app01/">Acessar App01</a>
    </div>
    <div class="card">
      <h2>App02</h2>
      <p>App com login delegado via Keycloak.</p>
      <a href="/app02/">Acessar App02</a>
    </div>
    <div class="card">
      <h2>App03</h2>
      <p>Todo List com roles e area restrita.</p>
      <a href="/app03/">Acessar App03</a>
    </div>
	<div class="card">
      <h2>App04</h2>
      <p>Todo Outros - Em implementação</p>
      <a href="/app04/">Acessar App04</a>
    </div>
  </div>
</body>
</html>
EOF

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

# Garantir que PubkeyAuthentication nao bloqueie o login por senha
sed -i 's/^PubkeyAuthentication yes/#PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Reiniciar o servico sshd para aplicar alteracoes
systemctl restart sshd

# Resetar senha do usuário vagrant para 'vagrant' (ajuste a senha se quiser)
echo "vagrant:vagrant" | chpasswd

# ---------- Final instructions echoed ----------
echo "[INFO] Provisionamento finalizado."
echo "Apps implantados:"
echo "  - App01: ${APP01_DIR} (gunicorn -> 5001) proxied at /app01/"
echo "  - App02: ${APP02_DIR} (gunicorn -> 5002) proxied at /app02/"
echo "  - App03: ${APP03_DIR} (gunicorn -> 5003) proxied at /app03/"
echo
echo "  - Acesse http://10.10.10.31"
echo
echo "ATENCAO: defina as variaveis do Keycloak para cada servico antes de reiniciar (ou edite os systemd unit files):"
echo "  KEYCLOAK_SERVER_URL (ex: http://10.10.10.30)"
echo "  KEYCLOAK_REALM (ex: myrealm)"
echo "  KEYCLOAK_CLIENT_ID (ex: app02)"
echo "  KEYCLOAK_CLIENT_SECRET (secreto do client)"
echo "  REDIRECT_URI (ex: http://<host>/app02/callback or http://<host>/app03/callback) - configure por app"
echo
echo "[DONE]"
