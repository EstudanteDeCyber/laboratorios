#!/bin/bash

set -e

# === CONFIGURAÇÕES ===
VPN_SUBNET="172.27.224.0/20"         # Subnet padrão do OpenVPN-AS
LAN_SUBNET="10.10.10.0/24"
LAN_INTERFACE="eth1"
VPN_DATA_DIR="/home/vagrant/openvpn/openvpn-data"
DOCKER_COMPOSE_FILE="/home/vagrant/openvpn/docker-compose.yml"
#OPENVPN_ADMIN_PASS="changeme123"     # Senha padrão do admin
SERVER_HOST="192.168.1.10"           # IP de acesso ao servidor web

# === CRIA DIRETÓRIO DE DADOS ===
mkdir -p "$VPN_DATA_DIR"

# === SOBE O CONTAINER ===
echo "[+] Subindo OpenVPN Access Server..."
docker compose -f "$DOCKER_COMPOSE_FILE" up -d

# === AGUARDA SUBIR ===
echo "[+] Aguardando OpenVPN iniciar..."
sleep 15

# === DEFINE SENHA DO ADMIN ===
#echo "[+] Configurando usuário admin..."
#docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --user openvpn --key "prop_superuser" --value "true" UserPropPut
#docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --user openvpn --key "type" --value "user_pass" UserPropPut
#docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --user openvpn --new_pass "$OPENVPN_ADMIN_PASS" SetLocalPassword

# === CONFIGURA ROTEAMENTO PARA A REDE INTERNA ===
echo "[+] Configurando acesso à rede interna via CLI..."
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --key "vpn.server.routing.gateway_redirect" --value "false" ConfigPut
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --key "vpn.server.routing.reroute_dns" --value "false" ConfigPut
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --key "vpn.server.routing.private_network.0" --value "$LAN_SUBNET" ConfigPut
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli start

# === HABILITA IP FORWARDING ===
echo "[+] Ativando IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf || echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

# === ADICIONA REGRA NAT ===
echo "[+] Adicionando NAT para tráfego da VPN para rede interna..."
iptables -t nat -C POSTROUTING -s "$VPN_SUBNET" -d "$LAN_SUBNET" -j MASQUERADE 2>/dev/null \
  || iptables -t nat -A POSTROUTING -s "$VPN_SUBNET" -d "$LAN_SUBNET" -j MASQUERADE
netfilter-persistent save

# === FINAL ===
echo "[✓] OpenVPN Access Server instalado e configurado."
echo "[→] Acesse: https://$SERVER_HOST:943/"
