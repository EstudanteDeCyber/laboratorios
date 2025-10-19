#!/bin/bash

set -e

# === CONFIGURACOES ===
VPN_SUBNET="172.27.224.0/20"         # Subnet padrão do OpenVPN-AS
LAN_SUBNET="10.10.10.0/24"
LAN_INTERFACE="eth1"
OPENVPN_ADMIN_PASS="changeme123"     # Senha padrão do admin
SERVER_HOST="192.168.1.10"           # IP de acesso ao servidor web

# === CRIA DIRETORIO DE DADOS ===
mkdir -p /home/vagrant/openvpn/openvpn-data

# === SOBE O CONTAINER ===
echo "[+] Subindo OpenVPN Access Server..."
docker compose -f /home/vagrant/openvpn/docker-compose.yml up -d

# === AGUARDA SUBIR ===
echo "[+] Aguardando OpenVPN iniciar..."
sleep 60

# === DEFINE SENHA DO ADMIN ===
echo "[+] Configurando usuario admin..."
#docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --user openvpn --key "prop_superuser" --value "true" UserPropPut
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --user openvpn --key "type" --value "user_pass" UserPropPut
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --user openvpn --new_pass "$OPENVPN_ADMIN_PASS" SetLocalPassword

# === CONFIGURA ROTEAMENTO PARA A REDE INTERNA ===
echo "[+] Configurando acesso a rede interna via CLI..."
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --key "vpn.server.routing.gateway_redirect" --value "false" ConfigPut
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --key "vpn.server.routing.reroute_dns" --value "false" ConfigPut
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli --key "vpn.server.routing.private_network.0" --value "$LAN_SUBNET" ConfigPut
docker exec openvpn-as /usr/local/openvpn_as/scripts/sacli start

# === HABILITA IP FORWARDING ===
echo "[+] Ativando IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf

# === ADICIONA REGRA NAT ===
echo "[+] Adicionando NAT para trafego da VPN para rede interna..."
sudo apt install -y netfilter-persistent
sudo iptables -t nat -C POSTROUTING -s "$VPN_SUBNET" -d "$LAN_SUBNET" -j MASQUERADE 2>/dev/null \
  || sudo iptables -t nat -A POSTROUTING -s "$VPN_SUBNET" -d "$LAN_SUBNET" -j MASQUERADE

# Altere para o seu IP na regra abaixo
sudo iptables -A INPUT -p tcp -s 192.168.1.100 --dport 22 -j ACCEPT
sudo netfilter-persistent save

# === FINAL ===
echo "[✓] OpenVPN Access Server instalado e configurado."
echo "[→] Acesse: https://$SERVER_HOST:9943/"
