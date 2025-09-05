#!/bin/bash

set -e

# === VALIDA ARGUMENTO ===
if [ -z "$1" ]; then
  echo "Uso: $0 <nome-do-usuario>"
  exit 1
fi

USERNAME="$1"
PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)

# === CRIA USUÁRIO COM SENHA GERADA ===
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --user "$USERNAME" --key "type" --value "user_pass" UserPropPut
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --user "$USERNAME" --new_pass "$PASSWORD" SetLocalPassword

echo "[✓] Usuário criado com sucesso."
echo "[→] Usuário: $USERNAME"
echo "[→] Usuário: $PASSWORD"
