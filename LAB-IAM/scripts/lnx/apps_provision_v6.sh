#!/bin/bash
set -euo pipefail

# ===============================================================
# Ajuste timezone
# ===============================================================
timedatectl set-timezone America/Sao_Paulo

# ===============================================================
# Dependências
# ===============================================================
echo "[INFO] Instalando dependências básicas..."
apt-get update -y
apt-get upgrade -y
apt-get install -y python3 python3-venv python3-pip build-essential nginx

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
import jwt
from urllib.parse import urlencode

# ===============================================================
# Configuração do Flask
# ===============================================================
app = Flask(__name__)
app.secret_key = os.getenv("APP_SECRET", "change_me")
app_id = os.getenv("APP_ID", "default-app-id")

# ===============================================================
# Variáveis de Ambiente do Keycloak
# ===============================================================
KEYCLOAK_SERVER_URL = os.getenv("KEYCLOAK_SERVER_URL")
REALM = os.getenv("REALM")
CLIENT_ID = os.getenv("CLIENT_ID")
CLIENT_SECRET = os.getenv("CLIENT_SECRET")
REDIRECT_URI = os.getenv("REDIRECT_URI")

# ===============================================================
# Variáveis de Controle
# ===============================================================
app01_configured = all([KEYCLOAK_SERVER_URL, REALM, CLIENT_ID, CLIENT_SECRET])
app02_configured = all([KEYCLOAK_SERVER_URL, REALM, CLIENT_ID, CLIENT_SECRET, REDIRECT_URI])
USER_INFO = {}
TODOS = {}

# ===============================================================
# Rotas Comuns
# ===============================================================
@app.route("/")
def index():
    return render_template('index.html')

# ===============================================================
# Rotas do App01 - Status
# ===============================================================
@app.route("/app01")
def app01():
    keycloak_status = "Ativado" if app01_configured else "Aguardando configuração do Keycloak - siga exercício 1"
    return render_template('app01.html', status=keycloak_status, keycloak_configured=app01_configured)

# ===============================================================
# Rotas do App02 - Login Delegado
# ===============================================================
@app.route("/app02")
def app02():
    if not app02_configured:
        return render_template("not_configured.html")

    if "user" in session:
        return render_template("app02_success.html", user=session["user"])

    auth_url = (
        f"{KEYCLOAK_SERVER_URL}/realms/{REALM}/protocol/openid-connect/auth?"
        f"client_id={CLIENT_ID}&"
        f"redirect_uri={REDIRECT_URI}&"
        f"response_type=code&"
        f"scope=openid"
    )
    return render_template(
        "app02.html",
        login_url=auth_url,
        forgot_password_url=url_for("app02_forgot_password")
    )

@app.route("/app02/callback")
def app02_callback():
    code = request.args.get("code")
    if not code:
        return render_template("app02_error.html"), 400

    token_url = f"{KEYCLOAK_SERVER_URL}/realms/{REALM}/protocol/openid-connect/token"
    data = {
        "grant_type": "authorization_code",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "redirect_uri": REDIRECT_URI,
        "code": code,
        "scope": "openid",
    }

    try:
        response = requests.post(token_url, data=data)
        response.raise_for_status()
        token_data = response.json()
        access_token = token_data.get("access_token")

        if access_token:
            try:
                decoded_token = jwt.decode(access_token, options={"verify_signature": False})
                print(f"DEBUG: Decoded Access Token: {decoded_token}")
            except Exception as e:
                print(f"ERROR: Failed to decode access token: {e}")
        else:
            return render_template("app02_error.html"), 400

        # Buscar dados do usuário
        userinfo_url = f"{KEYCLOAK_SERVER_URL}/realms/{REALM}/protocol/openid-connect/userinfo"
        headers = {"Authorization": f"Bearer {access_token}"}

        print(f"DEBUG: Access Token: {access_token}")
        print(f"DEBUG: Userinfo URL: {userinfo_url}")

        try:
            userinfo_response = requests.get(userinfo_url, headers=headers, verify=False)
            userinfo_response.raise_for_status()
            user_data = userinfo_response.json()
            print(f"DEBUG: Userinfo Response: {user_data}")
        except requests.exceptions.HTTPError as e:
            print(f"ERROR: HTTP Error accessing userinfo: {e}")
            print(f"ERROR: Userinfo Response Content: {userinfo_response.text}")
            return f"Erro ao obter informações do usuário: {e}", 500
        except Exception as e:
            print(f"ERROR: Unexpected error accessing userinfo: {e}")
            return f"Erro inesperado ao obter informações do usuário: {e}", 500

        # Guardar dados na sessão
        session["user"] = {
            "preferred_username": user_data.get("preferred_username"),
            "email": user_data.get("email"),
            "name": user_data.get("name"),
            "departamento": user_data.get("departamento"),
            "access_token": access_token,
        }

        return redirect(url_for("app02"))

    except requests.exceptions.RequestException as e:
        return f"Erro ao comunicar com o Keycloak: {e}", 500

@app.route("/app02/forgot_password")
def app02_forgot_password():
    if not app02_configured:
        return render_template("not_configured.html")

    forgot_password_url = (
        f"{KEYCLOAK_SERVER_URL}/realms/{REALM}/protocol/openid-connect/auth?"
        f"client_id={CLIENT_ID}&"
        f"redirect_uri={REDIRECT_URI}&"
        f"response_type=code&" \
        f"kc_action=UPDATE_PASSWORD&" \
        f"scope=openid"
    )
    return render_template("forgot_password.html", redirect_url=forgot_password_url)


@app.route("/app02/logout")
def app02_logout():
    session.pop("user", None)
    logout_url = (
        f"{KEYCLOAK_SERVER_URL}/realms/{REALM}/protocol/openid-connect/logout?"
        f"redirect_uri={url_for('app02', _external=True)}"
    )
    return redirect(logout_url)

# ===============================================================
# Rotas do App03 - Todo List + Roles
# ===============================================================
def get_roles_from_userinfo(userinfo):
    realm_access = userinfo.get("realm_access", {})
    return realm_access.get("roles", [])

@app.route("/app03")
def app03():
    if not app02_configured:
        return render_template('not_configured.html')

    if "user" not in session:
        return render_template('app03_dependency.html')

    user = session.get("user")
    roles = get_roles_from_userinfo(user) if user else []
    username = user.get("preferred_username") if user else None
    todos = TODOS.get(username, []) if username else []

    return render_template('app03.html', user=user, roles=roles, todos=todos)

@app.route("/app03/add_todo", methods=["POST"])
def add_todo():
    if "user" not in session:
        return redirect(url_for("app03"))

    text = request.form.get("text")
    username = session["user"].get("preferred_username")
    TODOS.setdefault(username, []).append(text)

    return redirect(url_for("app03"))

@app.route("/app03/admin")
def app03_admin():
    if not app02_configured:
        return render_template('not_configured.html')

    user = session.get("user")
    if not user:
        return redirect(url_for("app03"))

    roles = get_roles_from_userinfo(user)
    if "admin" not in roles:
        return render_template('app03_admin.html', access_denied=True)

    return render_template('app03_admin.html', access_denied=False)

# ===============================================================
# Execução
# ===============================================================
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
EOF

# ===============================================================
# Templates HTML
# ===============================================================
cat > "$PORTAL_DIR/templates/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Portal de Exercícios</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f9; text-align: center; padding: 50px; }
    .container { display: flex; justify-content: center; flex-wrap: wrap; gap: 20px; }
    .card { background: white; padding: 20px; border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); width: 250px; transition: transform 0.2s; }
    .card:hover { transform: translateY(-5px); }
    h1 { color: #333; margin-bottom: 40px; }
    h2 { color: #007BFF; margin-top: 0; }
    p { color: #666; }
    a, button { text-decoration: none; color: white; background: #007BFF; padding: 12px 24px; border-radius: 8px; display: inline-block; margin-top: 15px; cursor: pointer; border: none; font-size: 16px; font-weight: bold; transition: background 0.3s ease; }
    a:hover, button:hover { background: #0056b3; }
  </style>
</head>
<body>
  <h1>Portal de Exercícios com Keycloak</h1>
  <div class="container">
    <div class="card">
      <h2>App01</h2>
      <p>Verificação de Status do Keycloak</p>
      <a href="/app01">Acessar</a>
    </div>
    <div class="card">
      <h2>App02</h2>
      <p>Login Delegado (OIDC)</p>
      <a href="/app02">Acessar</a>
    </div>
    <div class="card">
      <h2>App03</h2>
      <p>Todo List com Controle de Acesso (RBAC)</p>
      <a href="/app03">Acessar</a>
    </div>
  </div>
</body>
</html>
EOF

cat > "$PORTAL_DIR/templates/app01.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>App01</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f9; text-align: center; padding: 50px; }
    .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); width: 300px; margin: 0 auto; }
    h2 { color: #007BFF; margin-top: 0; }
    .status { padding: 12px; border-radius: 8px; margin-top: 20px; display: inline-block; font-weight: bold; }
    .ativado { background: #28a745; color: white; }
    .desativado { background: #dc3545; color: white; animation: blink 1.5s infinite; }
    a, button { text-decoration: none; color: white; background: #6c757d; padding: 12px 24px; border-radius: 8px; display: inline-block; margin-top: 15px; cursor: pointer; border: none; font-size: 16px; font-weight: bold; transition: background 0.3s ease; }
    a:hover, button:hover { background: #5a6268; }
    @keyframes blink { 0%, 50%, 100% { opacity: 1; } 25%, 75% { opacity: 0.5; } }
  </style>
  <script>
    async function checkAuth(){
      const statusEl=document.getElementById('status');
      statusEl.textContent = 'Verificando...';
      const response=await fetch('/app01?check=true', {method: 'GET'});
      const data=await response.json();
      statusEl.textContent = data.status;
      if(data.status.includes('Ativado')){
        statusEl.className = 'status ativado';
      } else {
        statusEl.className = 'status desativado';
      }
    }
  </script>
</head>
<body>
  <div class="card">
  <h2>App01 - Status Keycloak</h2>
  {% if keycloak_configured %}
    <p>Keycloak configurado corretamente</p>
  {% else %}
    <p>Verifique a conexão com o Keycloak.</p>
  {% endif %}
  <div id="status" class="status {{ 'ativado' if keycloak_configured else 'desativado' }}">
    {{ status }}
  </div>
  <a href="/">Voltar ao Portal</a>
</div>
</body>
</html>
EOF

cat > "$PORTAL_DIR/templates/app02.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <title>App02</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        h1 { color: #333; }
        a {
            display: inline-block;
            margin: 10px;
            padding: 10px 15px;
            background-color: #007bff;
            color: white;
            text-decoration: none;
            border-radius: 5px;
        }
        a:hover { background-color: #0056b3; }
    </style>
</head>
<body>
    <h1>App02</h1>
    <a href="{{ login_url }}">Entrar com Keycloak</a>
    <a href="{{ forgot_password_url }}">Esqueci a senha</a>
</body>
</html>
EOF

cat > "$PORTAL_DIR/templates/app02_error.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Erro de Login</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f9; text-align: center; padding: 50px; }
    .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); width: 350px; margin: 0 auto; }
    h2 { color: #dc3545; margin-top: 0; }
    p { color: #666; margin-top: 20px; font-weight: bold; }
    a { color: #007bff; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <div class="card">
    <h2>Erro no Login</h2>
    <p>
      Não foi possível completar o login.  
      Por favor, <a href="/app02">volte para a página de login</a>.  
      Se o problema persistir, pode ser necessário criar um usuário no Keycloak.
    </p>
  </div>
</body>
</html>
EOF

cat > "$PORTAL_DIR/templates/app02_success.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Login Concluído</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style> body { font-family: 'Inter', sans-serif; } </style>
</head>
<body class="bg-gray-100 flex items-center justify-center min-h-screen p-4">
  <div class="bg-white rounded-xl shadow-lg p-8 w-full max-w-md text-center">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 text-green-500 mx-auto mb-4" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
    </svg>
    <h1 class="text-3xl font-bold text-green-600 mb-2">Login efetuado com sucesso no APP02!</h1>
    <p class="text-gray-600 mb-6">Suas informações de usuário:</p>

    <div class="space-y-4 text-left">
      <div class="bg-green-50 border border-green-200 rounded-lg p-4">
        <p class="text-sm text-green-700 font-semibold">Login:</p>
        <p class="text-lg text-green-800 font-bold break-all">{{ user.preferred_username }}</p>
      </div>
      <div class="bg-green-50 border border-green-200 rounded-lg p-4">
        <p class="text-sm text-green-700 font-semibold">Email:</p>
        <p class="text-lg text-green-800 font-bold break-all">{{ user.email }}</p>
      </div>
      <div class="bg-green-50 border border-green-200 rounded-lg p-4">
        <p class="text-sm text-green-700 font-semibold">Departamento:</p>
        <p class="text-lg text-green-800 font-bold break-all">
          {{ user.departamento if user.departamento else "N/A" }}
        </p>
      </div>
    </div>

    <div class="mt-6">
      <a href="{{ url_for('app02_logout') }}"
         class="bg-red-600 hover:bg-red-700 text-white font-bold py-2 px-4 rounded-lg">
         Logout
      </a>
    </div>
  </div>
</body>
</html>
EOF

cat > "$PORTAL_DIR/templates/forgot_password.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Esqueci a Senha</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 flex items-center justify-center min-h-screen">
  <div class="bg-white shadow-md rounded-xl p-8 w-full max-w-sm text-center">
    <h1 class="text-xl font-bold mb-4">Esqueci a Senha</h1>
    <a href="{{ redirect_url }}"
       class="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded-lg inline-block">
       Alterar minha senha no Keycloak
    </a>
  </div>
</body>
</html>
EOF

cat > "$PORTAL_DIR/templates/app03_dependency.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>App03 - Aguardando Login</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f9; text-align: center; padding: 50px; }
    .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); width: 350px; margin: 0 auto; }
    h2 { color: #dc3545; margin-top: 0; }
    p { color: #666; margin-top: 20px; font-weight: bold; }
    .status { padding: 12px; border-radius: 8px; margin-top: 20px; display: inline-block; font-weight: bold; animation: blink 1.5s infinite; background: #ffc107; color: black; }
    a, button { text-decoration: none; color: white; background: #007BFF; padding: 12px 24px; border-radius: 8px; display: inline-block; margin-top: 15px; cursor: pointer; border: none; font-size: 16px; font-weight: bold; transition: background 0.3s ease; }
    a:hover, button:hover { background: #0056b3; }
    @keyframes blink { 0%, 50%, 100% { opacity: 1; } 25%, 75% { opacity: 0.5; } }
  </style>
</head>
<body>
  <div class="card">
    <h2>App03 - Dependência</h2>
    <p>
      Para usar o **App03**, você precisa se autenticar primeiro.<br>
      Acesse o **App02** para realizar o login.
    </p>
    <a href="/app02" class="button">Ir para o App02</a>
  </div>
</body>
</html>
EOF

cat > "$PORTAL_DIR/templates/app03.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>App03 - Todo List</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f9; text-align: center; padding: 50px; }
    .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); width: 350px; margin: 0 auto; }
    h2 { color: #007BFF; margin-top: 0; }
    h3 { color: #333; margin-top: 25px; }
    p { color: #666; }
    a, button { text-decoration: none; color: white; background: #007BFF; padding: 12px 24px; border-radius: 8px; display: inline-block; margin-top: 15px; cursor: pointer; border: none; font-size: 16px; font-weight: bold; transition: background 0.3s ease; }
    a:hover, button:hover { background: #0056b3; }
    a.logout-btn { background: #dc3545; }
    a.logout-btn:hover { background: #c82333; }
    a.admin-btn { background: #ffc107; color: black; }
    a.admin-btn:hover { background: #e0a800; }
    input[type="text"] { width: 80%; padding: 10px; border: 1px solid #ccc; border-radius: 4px; }
    ul { list-style: none; padding: 0; text-align: left; margin-top: 20px; }
    li { background: #eee; padding: 10px; border-radius: 6px; margin-bottom: 8px; }
    .role { background: #6c757d; color: white; padding: 4px 10px; border-radius: 15px; font-size: 0.8em; margin: 0 2px; }
  </style>
</head>
<body>
  <div class="card">
    <h2>App03 - To-Do List</h2>
    {% if user %}
      <p>Bem-vindo, <strong>{{ user['preferred_username'] }}</strong>!</p>
      {% if roles %}
        <p><strong>Roles:</strong>
          {% for role in roles %}
            <span class="role">{{ role }}</span>
          {% endfor %}
        </p>
      {% endif %}
      <hr>
      <h3>Minhas Tarefas</h3>
      {% if todos %}
      <ul>
        {% for t in todos %}
          <li>{{ t }}</li>
        {% endfor %}
      </ul>
      {% else %}
        <p>Nenhuma tarefa adicionada ainda.</p>
      {% endif %}
      <form method="post" action="/app03/add_todo">
        <input name="text" type="text" placeholder="Nova tarefa">
        <button type="submit">Adicionar</button>
      </form>
      {% if 'admin' in roles %}
        <a href="/app03/admin" class="admin-btn">Área Admin</a>
      {% endif %}
      <a href="/app02/logout" class="logout-btn">Sair</a>
    {% else %}
      <p>Você não está autenticado.</p>
      <a href="/app02" class="login-btn">Entrar com Keycloak</a>
    {% endif %}
  </div>
</body>
</html>
EOF

cat > "$PORTAL_DIR/templates/app03_admin.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>App03 - Área Admin</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f9; text-align: center; padding: 50px; }
    .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); width: 350px; margin: 0 auto; }
    h2 { color: #007BFF; margin-top: 0; }
    p { color: #666; margin-top: 20px; }
    .alert-error { background: #ffcccc; color: #cc0000; padding: 15px; border-radius: 8px; margin-top: 20px; font-weight: bold; }
    .alert-success { background: #d4edda; color: #155724; padding: 15px; border-radius: 8px; margin-top: 20px; font-weight: bold; }
    a, button { text-decoration: none; color: white; background: #007BFF; padding: 12px 24px; border-radius: 8px; display: inline-block; margin-top: 15px; cursor: pointer; border: none; font-size: 16px; font-weight: bold; transition: background 0.3s ease; }
    a:hover, button:hover { background: #0056b3; }
  </style>
</head>
<body>
  <div class="card">
    <h2>Área Administrativa</h2>
    {% if access_denied %}
      <p class="alert-error">Acesso negado: Somente administradores.</p>
    {% else %}
      <p class="alert-success">Bem-vindo à área administrativa!</p>
      <p>Conteúdo restrito para usuários com a role 'admin'.</p>
    {% endif %}
    <a href="/app03">Voltar ao App03</a>
  </div>
</body>
</html>
EOF

cat > "$PORTAL_DIR/templates/not_configured.html" <<'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Aguardando Configuração</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f9; text-align: center; padding: 50px; }
    .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); width: 350px; margin: 0 auto; }
    h2 { color: #007BFF; margin-top: 0; }
    p { color: #666; margin-top: 20px; font-weight: bold; }
    .status { padding: 12px; border-radius: 8px; margin-top: 20px; display: inline-block; font-weight: bold; animation: blink 1.5s infinite; }
    .desativado { background: #dc3545; color: white; }
    @keyframes blink { 0%, 50%, 100% { opacity: 1; } 25%, 75% { opacity: 0.5; } }
  </style>
</head>
<body>
  <div class="card">
    <h2>Aguardando Configuração</h2>
    <p>
      Para continuar, siga as instruções dos exercícios para configurar o Keycloak e as variáveis de ambiente.
    </p>
    <div class="status desativado">
      Aguardando
    </div>
  </div>
</body>
</html>
EOF

# ===============================================================
# Dependências Python
# ===============================================================
cat > "$PORTAL_DIR/requirements.txt" <<'EOF'
Flask>=2.0
requests>=2.20
gunicorn>=20
PyJWT>=2.0.0
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
Environment="KEYCLOAK_SERVER_URL=${KEYCLOAK_SERVER_URL:-}"
Environment="REALM=${REALM:-}"
Environment="CLIENT_ID=${CLIENT_ID:-}"
Environment="CLIENT_SECRET=${CLIENT_SECRET:-}"
Environment="REDIRECT_URI=${REDIRECT_URI:-}"
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
rm -f /etc/nginx/sites-enabled/default

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

sudo apt autoremove -y
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

echo "  KEYCLOAK -->> http://10.10.10.30"
echo "  APPS     -->> http://10.10.10.31"