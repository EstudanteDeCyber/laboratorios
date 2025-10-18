set -euo pipefail

### Provision script: App01 (existing) + App02 + App03 (Todo List)
### Pads: /var/www/app01, /var/www/app02, /var/www/app03
### Uses: www-data, venv per app, gunicorn, systemd services, nginx reverse proxy

set -e

# ---------- Configurações (ajuste se necessário) ----------
APP01_DIR="/var/www/app01"
APP02_DIR="/var/www/app02"
APP03_DIR="/var/www/app03"

# venv paths will be per-app (constructed below)
PYTHON_BIN="/usr/bin/python3"

SERVICE_FILE1="/etc/systemd/system/app01.service"
SERVICE_FILE2="/etc/systemd/system/app02.service"
SERVICE_FILE3="/etc/systemd/system/app03.service"

NGINX_CONF="/etc/nginx/sites-available/apps"
NGINX_LINK="/etc/nginx/sites-enabled/apps"

# Resetar senha do usuário vagrant para 'vagrant' (ajuste a senha se quiser)
echo "vagrant:vagrant" | chpasswd

echo "[INFO] SSH ajustado para login por senha com usuário 'vagrant'."

# Default gunicorn workers
GUNICORN_WORKERS=3

# You may export these BEFORE running the script, or edit later in the systemd files:
# KEYCLOAK_SERVER_URL, KEYCLOAK_REALM, KEYCLOAK_CLIENT_ID, KEYCLOAK_CLIENT_SECRET, REDIRECT_URI, APP_SECRET
# Example:
# export KEYCLOAK_SERVER_URL="http://10.10.10.30"
# export KEYCLOAK_REALM="myrealm"

# ---------- Pacotes base ----------
echo "[INFO] Atualizando pacotes e instalando dependências base..."
apt-get update -y && apt-get upgrade -y
apt-get install -y python3 python3-venv python3-dev build-essential nginx git curl

# Ensure www-data user exists (default on Debian/Ubuntu)
id -u www-data >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin www-data

# ---------- Função utilitária para criar app (venv, estruturas) ----------
create_app_structure() {
  local APP_DIR="$1"
  local APP_NAME="$2"

  echo "[INFO] Criando estrutura para ${APP_NAME} em ${APP_DIR}..."
  mkdir -p "${APP_DIR}"
  chown -R www-data:www-data "${APP_DIR}"
  chmod 755 "${APP_DIR}"
  # create venv
  ${PYTHON_BIN} -m venv "${APP_DIR}/venv"
  # ensure pip is upgraded
  "${APP_DIR}/venv/bin/python" -m pip install --upgrade pip >/dev/null
}

# ---------- Criar diretórios e venvs ----------
create_app_structure "${APP01_DIR}" "app01"
create_app_structure "${APP02_DIR}" "app02"
create_app_structure "${APP03_DIR}" "app03"

# ---------- DEPLOY: App01 (preserve app01 behavior) ----------
# If you already have app01 code, copy it into $APP01_DIR before running script.
# For idempotency we will create a minimal placeholder if no app exists.

# Abre o bloco IF
if [ ! -f "${APP01_DIR}/app.py" ]; then
  cat > "${APP01_DIR}/app.py" <<'EOF'
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
EOF
fi # <--- O 'fi' deve fechar o bloco IF aqui.

# Agora, o bloco para criar o requirements.txt
# Este bloco deve estar FORA do IF
cat > "${APP01_DIR}/requirements.txt" <<'EOF'
Flask>=2.0
gunicorn>=20
EOF

# install requirements for app01
"${APP01_DIR}/venv/bin/pip" install -r "${APP01_DIR}/requirements.txt" >/dev/null

# ---------- DEPLOY: App02 (login delegated app) ----------
# app02 code (simple OIDC auth flow redirection to Keycloak)
cat > "${APP02_DIR}/app.py" <<'EOF'
import os
from flask import Flask, redirect, request, session, url_for, render_template_string
import requests
from urllib.parse import urlencode

app = Flask(__name__)
app.secret_key = os.getenv("APP02_SECRET", "change_me")

KEYCLOAK_URL = os.getenv("KEYCLOAK_SERVER_URL")
REALM = os.getenv("KEYCLOAK_REALM")
CLIENT_ID = os.getenv("KEYCLOAK_CLIENT_ID")
CLIENT_SECRET = os.getenv("KEYCLOAK_CLIENT_SECRET")
REDIRECT_URI = os.getenv("REDIRECT_URI")  # e.g. http://10.10.10.32:5002/callback

if not all([KEYCLOAK_URL, REALM, CLIENT_ID, CLIENT_SECRET, REDIRECT_URI]):
    # Will allow local testing if you set env vars before running; otherwise fail fast.
    raise RuntimeError("Missing Keycloak configuration: ensure KEYCLOAK_SERVER_URL, REALM, CLIENT_ID, CLIENT_SECRET, REDIRECT_URI are set")

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
    kc_logout = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/logout"
    params = {"post_logout_redirect_uri": request.host_url}
    return redirect(f"{kc_logout}?{urlencode(params)}")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002, debug=True)
EOF

chown -R www-data:www-data "${APP02_DIR}"

cat > "${APP02_DIR}/requirements.txt" <<'EOF'
Flask>=2.0
requests>=2.20
gunicorn>=20
EOF

"${APP02_DIR}/venv/bin/pip" install -r "${APP02_DIR}/requirements.txt" >/dev/null

# ---------- DEPLOY: App03 (Todo list) ----------
# app03 code — copy of the earlier Todo app (roles-based)
cat > "${APP03_DIR}/app03.py" <<'EOF'
import os
from flask import Flask, redirect, request, session, url_for, render_template_string, jsonify, abort
from urllib.parse import urlencode
import requests
from functools import wraps

app = Flask(__name__)
app.secret_key = os.getenv("APP_SECRET", "change_this_in_prod")

KEYCLOAK_URL = os.getenv("KEYCLOAK_SERVER_URL")
REALM = os.getenv("KEYCLOAK_REALM")
CLIENT_ID = os.getenv("KEYCLOAK_CLIENT_ID")
CLIENT_SECRET = os.getenv("KEYCLOAK_CLIENT_SECRET")
REDIRECT_URI = os.getenv("REDIRECT_URI")  # e.g. http://10.10.10.32:5003/callback

if not all([KEYCLOAK_URL, REALM, CLIENT_ID, CLIENT_SECRET, REDIRECT_URI]):
    raise RuntimeError("Missing Keycloak configuration (check environment variables)")

TODOS = {}

INDEX_TPL = """
<h1>App03 - Todo List (Keycloak)</h1>
{% if user %}
  <p>Olá, <strong>{{ user.get('preferred_username') }}</strong> (roles: {{ roles }})</p>
  <p><a href="{{ url_for('logout') }}">Logout</a></p>

  <h2>Seus Todos</h2>
  <ul>
    {% for t in todos %}
      <li>{{ t }}</li>
    {% endfor %}
  </ul>

  <form method="post" action="{{ url_for('add_todo') }}">
    <input name="text" placeholder="Nova tarefa" required>
    <button type="submit">Adicionar</button>
  </form>

  {% if 'admin' in roles %}
    <hr>
    <h3>Área Admin</h3>
    <p><a href="{{ url_for('admin') }}">Ir para /admin</a></p>
  {% endif %}

{% else %}
  <p><a href="{{ url_for('login') }}">Entrar com Keycloak</a></p>
{% endif %}
"""

ADMIN_TPL = """
<h1>Admin Area</h1>
<p>Somente para role <strong>admin</strong>.</p>
<p><a href="{{ url_for('index') }}">Voltar</a></p>
"""

def keycloak_auth_url():
    params = {
        "client_id": CLIENT_ID,
        "response_type": "code",
        "scope": "openid profile email",
        "redirect_uri": REDIRECT_URI
    }
    return f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/auth?{urlencode(params)}"

def exchange_code_for_token(code):
    token_url = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/token"
    data = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": REDIRECT_URI,
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET
    }
    r = requests.post(token_url, data=data)
    r.raise_for_status()
    return r.json()

def get_userinfo(access_token):
    userinfo_url = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/userinfo"
    r = requests.get(userinfo_url, headers={"Authorization": f"Bearer {access_token}"})
    if r.status_code != 200:
        return None
    return r.json()

def get_roles_from_userinfo(userinfo):
    realm_access = userinfo.get("realm_access", {})
    roles = realm_access.get("roles", [])
    if not roles:
        roles = userinfo.get("roles", [])
    return roles

def login_required(fn):
    from functools import wraps
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if "user" not in session:
            return redirect(url_for("login"))
        return fn(*args, **kwargs)
    return wrapper

def roles_required(required_roles):
    def decorator(fn):
        from functools import wraps
        @wraps(fn)
        def wrapper(*args, **kwargs):
            user = session.get("user")
            if not user:
                return redirect(url_for("login"))
            roles = get_roles_from_userinfo(user)
            if not any(r in roles for r in required_roles):
                abort(403)
            return fn(*args, **kwargs)
        return wrapper
    return decorator

def bearer_auth_required(fn):
    from functools import wraps
    @wraps(fn)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "missing_token"}), 401
        token = auth.split(" ", 1)[1]
        userinfo = get_userinfo(token)
        if not userinfo:
            return jsonify({"error": "invalid_token"}), 401
        request.userinfo = userinfo
        return fn(*args, **kwargs)
    return wrapper

@app.route("/")
def index():
    user = session.get("user")
    roles = get_roles_from_userinfo(user) if user else []
    username = user.get("preferred_username") if user else None
    todos = TODOS.get(username, []) if username else []
    return render_template_string(INDEX_TPL, user=user, roles=roles, todos=todos)

@app.route("/login")
def login():
    return redirect(keycloak_auth_url())

@app.route("/callback")
def callback():
    code = request.args.get("code")
    if not code:
        return "Missing code", 400
    token = exchange_code_for_token(code)
    access_token = token.get("access_token")
    if not access_token:
        return "Failed to obtain access token", 400
    userinfo = get_userinfo(access_token)
    if not userinfo:
        return "Failed to obtain userinfo", 400
    session["user"] = userinfo
    session["access_token"] = access_token
    username = userinfo.get("preferred_username")
    if username not in TODOS:
        TODOS[username] = []
    return redirect(url_for("index"))

@app.route("/logout")
def logout():
    session.clear()
    kc_logout = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/logout"
    params = {"post_logout_redirect_uri": request.host_url}
    return redirect(f"{kc_logout}?{urlencode(params)}")

@app.route("/add", methods=["POST"])
@login_required
def add_todo():
    text = request.form.get("text")
    if not text:
        return redirect(url_for("index"))
    username = session["user"].get("preferred_username")
    TODOS.setdefault(username, []).append(text)
    return redirect(url_for("index"))

@app.route("/admin")
@roles_required(["admin"])
def admin():
    return render_template_string(ADMIN_TPL)

@app.route("/api/todos", methods=["GET"])
@bearer_auth_required
def api_get_todos():
    username = request.userinfo.get("preferred_username")
    return jsonify({"todos": TODOS.get(username, [])})

@app.route("/api/todos", methods=["POST"])
@bearer_auth_required
def api_add_todo():
    data = request.json or {}
    text = data.get("text")
    if not text:
        return jsonify({"error": "missing_text"}), 400
    username = request.userinfo.get("preferred_username")
    TODOS.setdefault(username, []).append(text)
    return jsonify({"ok": True, "todos": TODOS[username]}), 201

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5003, debug=True)
EOF

chown -R www-data:www-data "${APP03_DIR}"

cat > "${APP03_DIR}/requirements.txt" <<'EOF'
Flask>=2.0
requests>=2.20
gunicorn>=20
EOF

"${APP03_DIR}/venv/bin/pip" install -r "${APP03_DIR}/requirements.txt" >/dev/null

# ---------- Systemd unit files (consistent pattern) ----------
# Note: Environment variables intentionally use the ${VAR:-} pattern so you can set them
# in the provisioning scope or in an env file and they will be applied to systemd when daemon-reload runs.

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
Environment="APP02_SECRET=${APP02_SECRET:-}"
ExecStart=${APP02_DIR}/venv/bin/gunicorn --workers ${GUNICORN_WORKERS} --bind 0.0.0.0:5002 app:app

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

# Reload systemd and enable services
systemctl daemon-reload
systemctl enable --now app01.service || true
systemctl enable app02.service || true
systemctl enable app03.service || true

# ---------- Nginx config: reverse proxy for three apps ----------
cat > "${NGINX_CONF}" <<'EOF'
upstream app01 {
    server 127.0.0.1:5001;
}
upstream app02 {
    server 127.0.0.1:5002;
}
upstream app03 {
    server 127.0.0.1:5003;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # App01 (root /app01)
    location /app01/ {
        proxy_pass http://app01/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # App02 (root /app02)
    location /app02/ {
        proxy_pass http://app02/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # App03 (root /app03)
    location /app03/ {
        proxy_pass http://app03/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # convenience direct access for testing
    location / {
        return 200 "Reverse proxy for app01/app02/app03. Use /app01/, /app02/ or /app03/\\n";
    }
}
EOF

# enable nginx site
ln -sf "${NGINX_CONF}" "${NGINX_LINK}"
nginx -t && systemctl reload nginx

# ---------- Permissions ----------
chown -R www-data:www-data "${APP01_DIR}" "${APP02_DIR}" "${APP03_DIR}"
chmod -R 750 "${APP01_DIR}" "${APP02_DIR}" "${APP03_DIR}"

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

# ---------- Final instructions echoed ----------
echo "[INFO] Provisionamento finalizado."
echo "Apps implantados:"
echo "  - App01: ${APP01_DIR} (gunicorn -> 5001) proxied at /app01/"
echo "  - App02: ${APP02_DIR} (gunicorn -> 5002) proxied at /app02/"
echo "  - App03: ${APP03_DIR} (gunicorn -> 5003) proxied at /app03/ (todo list com roles)"
echo
echo "ATENÇÃO: defina as variáveis do Keycloak para cada serviço antes de reiniciar (ou edite os systemd unit files):"
echo "  KEYCLOAK_SERVER_URL (ex: http://10.10.10.30)"
echo "  KEYCLOAK_REALM (ex: myrealm)"
echo "  KEYCLOAK_CLIENT_ID (ex: app02)"
echo "  KEYCLOAK_CLIENT_SECRET (secreto do client)"
echo "  REDIRECT_URI (ex: http://<host>/app02/callback or http://<host>/app03/callback) - configure por app"
echo
echo "[DONE]"