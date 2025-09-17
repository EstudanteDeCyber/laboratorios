#!/bin/bash
set -euo pipefail

# ===============================================================
# Variáveis
# ===============================================================
PORTAL_DIR="/var/www/portal"
VENV_DIR="$PORTAL_DIR/venv"
NGINX_CONF="/etc/nginx/sites-available/portal.conf"

# ===============================================================
# Estrutura do App
# ===============================================================
mkdir -p "$PORTAL_DIR/templates"
mkdir -p "$PORTAL_DIR/static"

# ----------------- app.py -----------------
cat > "$PORTAL_DIR/app.py" <<'EOF'
import os
from flask import Flask, render_template, jsonify, redirect, request, session, url_for
import requests
from urllib.parse import urlencode

app = Flask(__name__)
app.secret_key = os.getenv("APP_SECRET", "change_me")

# Variáveis comuns de Keycloak (via systemd Environment)
KEYCLOAK_SERVER_URL = os.getenv("KEYCLOAK_SERVER_URL")
KEYCLOAK_REALM = os.getenv("KEYCLOAK_REALM")
KEYCLOAK_CLIENT_ID = os.getenv("KEYCLOAK_CLIENT_ID")
KEYCLOAK_CLIENT_SECRET = os.getenv("KEYCLOAK_CLIENT_SECRET")
REDIRECT_URI = os.getenv("REDIRECT_URI")

# Página inicial
@app.route("/")
def home():
    return render_template("index.html")

# ----------------- App01 -----------------
@app.route("/app01")
def app01_index():
    use_keycloak = all([KEYCLOAK_SERVER_URL, KEYCLOAK_REALM, KEYCLOAK_CLIENT_ID, KEYCLOAK_CLIENT_SECRET])
    return render_template("app01_index.html", keycloak_enabled=use_keycloak)

@app.route("/app01/check_auth", methods=["POST"])
def app01_check_auth():
    if not all([KEYCLOAK_SERVER_URL, KEYCLOAK_REALM, KEYCLOAK_CLIENT_ID, KEYCLOAK_CLIENT_SECRET]):
        return jsonify({"message": "Keycloak não configurado"}), 200
    else:
        return jsonify({"message": "App01 autenticado no Keycloak"}), 200

# ----------------- App02 -----------------
@app.route("/app02")
def app02_index():
    return render_template("app02_index.html", user=session.get("user"))

@app.route("/app02/login")
def app02_login():
    params = {
        "client_id": KEYCLOAK_CLIENT_ID,
        "response_type": "code",
        "scope": "openid profile email",
        "redirect_uri": REDIRECT_URI
    }
    url = f"{KEYCLOAK_SERVER_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/auth?{urlencode(params)}"
    return redirect(url)

@app.route("/app02/callback")
def app02_callback():
    code = request.args.get("code")
    token_url = f"{KEYCLOAK_SERVER_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/token"
    data = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": REDIRECT_URI,
        "client_id": KEYCLOAK_CLIENT_ID,
        "client_secret": KEYCLOAK_CLIENT_SECRET
    }
    token = requests.post(token_url, data=data).json()
    userinfo_url = f"{KEYCLOAK_SERVER_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/userinfo"
    userinfo = requests.get(userinfo_url, headers={"Authorization": f"Bearer {token['access_token']}"}).json()
    session["user"] = userinfo
    return render_template("app02_callback.html", user=userinfo)

@app.route("/app02/logout")
def app02_logout():
    session.clear()
    kc_logout = f"{KEYCLOAK_SERVER_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/logout"
    return redirect(kc_logout)

# ----------------- App03 -----------------
TODOS = {}

def get_roles_from_userinfo(userinfo):
    realm_access = userinfo.get("realm_access", {})
    return realm_access.get("roles", [])

@app.route("/app03")
def app03_index():
    user = session.get("user")
    roles = get_roles_from_userinfo(user) if user else []
    username = user.get("preferred_username") if user else None
    todos = TODOS.get(username, []) if username else []
    return render_template("app03_index.html", user=user, roles=roles, todos=todos)

@app.route("/app03/add", methods=["POST"])
def app03_add_todo():
    if "user" not in session: return redirect(url_for("app02_login"))
    text = request.form.get("text")
    username = session["user"].get("preferred_username")
    TODOS.setdefault(username, []).append(text)
    return redirect(url_for("app03_index"))

@app.route("/app03/admin")
def app03_admin():
    user = session.get("user")
    if not user: return redirect(url_for("app02_login"))
    roles = get_roles_from_userinfo(user)
    if "admin" not in roles:
        return "<h1>Acesso negado: somente admin</h1>", 403
    return "<h1>Área Admin - restrita à role admin</h1>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

# ===============================================================
# Templates HTML
# ===============================================================

# Página inicial
cat > "$PORTAL_DIR/templates/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>Portal de Exercícios</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f9; text-align: center; padding: 50px; }
    .container { display: flex; justify-content: center; gap: 20px; }
    .card {
      background: white; padding: 20px; border-radius: 8px;
      box-shadow: 0 2px 6px rgba(0,0,0,0.2);
      width: 200px;
    }
    a { text-decoration: none; color: white; background: #007BFF; padding: 10px; border-radius: 5px; display: block; margin-top: 10px; }
  </style>
</head>
<body>
  <h1>Portal de Exercícios com Keycloak</h1>
  <div class="container">
    <div class="card">
      <h2>App01</h2>
      <p>Status Keycloak</p>
      <a href="/app01">Ir</a>
    </div>
    <div class="card">
      <h2>App02</h2>
      <p>Login Delegado</p>
      <a href="/app02">Ir</a>
    </div>
    <div class="card">
      <h2>App03</h2>
      <p>Todo List + Roles</p>
      <a href="/app03">Ir</a>
    </div>
  </div>
</body>
</html>
EOF

# App01
cat > "$PORTAL_DIR/templates/app01_index.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>App01</title>
  <style>
    body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
    .status { padding: 10px; border-radius: 5px; margin-top: 20px; display: inline-block; }
    .desativado { background: red; color: white; animation: blink 1s infinite; }
    .ativado { background: green; color: white; }
    @keyframes blink { 0%, 50%, 100% { opacity: 1; } 25%, 75% { opacity: 0; } }
  </style>
  <script>
    async function checkAuth() {
      const response = await fetch('/app01/check_auth', { method: 'POST' });
      const data = await response.json();
      alert(data.message);
      const statusEl = document.getElementById('status');
      if(data.message.includes('não configurado')) {
        statusEl.textContent = 'Desativado';
        statusEl.className = 'status desativado';
      } else {
        statusEl.textContent = 'Ativado';
        statusEl.className = 'status ativado';
      }
    }
  </script>
</head>
<body>
  <h1>App01 - Status Keycloak</h1>
  <button onclick="checkAuth()">Verificar</button>
  <div id="status" class="status desativado">Desativado</div>
</body>
</html>
EOF

# App02
cat > "$PORTAL_DIR/templates/app02_index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>App02</title></head>
<body>
  <h1>App02 - Login Delegado</h1>
  {% if user %}
    <p>Usuário: {{ user['preferred_username'] }}</p>
    <a href="/app02/logout">Sair</a>
  {% else %}
    <p>Você não está logado</p>
    <a href="/app02/login">Entrar com Keycloak</a>
  {% endif %}
</body>
</html>
EOF

cat > "$PORTAL_DIR/templates/app02_callback.html" <<'EOF'
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>App02 Callback</title></head>
<body>
  <h2>Autenticado com sucesso!</h2>
  <p>Usuário: {{ user['preferred_username'] }}</p>
  <a href="/app02">Voltar</a>
</body>
</html>
EOF

# App03
cat > "$PORTAL_DIR/templates/app03_index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>App03</title></head>
<body>
  <h1>App03 - Todo List</h1>
  {% if user %}
    <p>Usuário: {{ user['preferred_username'] }}</p>
    <p>Roles: {{ roles }}</p>
    <ul>
      {% for t in todos %}<li>{{ t }}</li>{% endfor %}
    </ul>
    <form method="post" action="/app03/add">
      <input name="text" placeholder="Nova tarefa">
      <button type="submit">Adicionar</button>
    </form>
    <a href="/app02/logout">Sair</a>
    {% if 'admin' in roles %}
      <p><a href="/app03/admin">Ir para admin</a></p>
    {% endif %}
  {% else %}
    <p>Você não está logado</p>
    <a href="/app02/login">Entrar</a>
  {% endif %}
</body>
</html>
EOF

# ===============================================================
# Dependências
# ===============================================================
cat > "$PORTAL_DIR/requirements.txt" <<'EOF'
Flask>=2.0
requests>=2.20
gunicorn>=20
EOF

python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/pip" install -r "$PORTAL_DIR/requirements.txt"

# ===============================================================
# Systemd Service
# ===============================================================
cat > /etc/systemd/system/portal.service <<EOF
[Unit]
Description=Gunicorn instance to serve unified portal
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$PORTAL_DIR
Environment="PATH=$VENV_DIR/bin"
Environment="KEYCLOAK_SERVER_URL=\${KEYCLOAK_SERVER_URL:-}"
Environment="KEYCLOAK_REALM=\${KEYCLOAK_REALM:-}"
Environment="KEYCLOAK_CLIENT_ID=\${KEYCLOAK_CLIENT_ID:-}"
Environment="KEYCLOAK_CLIENT_SECRET=\${KEYCLOAK_CLIENT_SECRET:-}"
Environment="REDIRECT_URI=\${REDIRECT_URI:-}"
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind 0.0.0.0:5000 app:app

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable portal
systemctl restart portal

# ===============================================================
# Nginx Config
# ===============================================================
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;

    location / {
        proxy_pass http://127.0.0.1:5000/;
    }

    location /app01 {
        proxy_pass http://127.0.0.1:5000/app01;
    }

    location /app02 {
        proxy_pass http://127.0.0.1:5000/app02;
    }

    location /app03 {
        proxy_pass http://127.0.0.1:5000/app03;
    }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/portal.conf
nginx -t && systemctl reload nginx

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

echo "[INFO] Setup concluído!"
echo "App01 em http://10.10.10.31:81/app01"
echo "App02 em http://10.10.10.31:82/app02"
echo "App03 em http://10.10.10.31:83/app03"
APP
