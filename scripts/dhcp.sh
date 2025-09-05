#!/bin/bash

set -e

# Variáveis
INTERFACE="eth1"                     # Substitua pela interface usada
STATIC_IP="10.10.10.10"
NETMASK="255.255.255.0"
DHCP_RANGE_START="10.10.10.120"
DHCP_RANGE_END="10.10.10.200"
LEASE_TIME="12h"
DNSMASQ_CONF="/etc/dnsmasq.conf"

echo "[+] Instalando dnsmasq..."
apt update -y && apt install -y dnsmasq

echo "[+] Configurando IP fixo na interface $INTERFACE..."
ip addr flush dev $INTERFACE
ip addr add ${STATIC_IP}/24 dev $INTERFACE
ip link set $INTERFACE up

echo "[+] Criando backup da configuração original do dnsmasq..."
cp $DNSMASQ_CONF ${DNSMASQ_CONF}.bak

echo "[+] Gerando nova configuração do dnsmasq..."
cat > $DNSMASQ_CONF <<EOF
interface=$INTERFACE
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,$LEASE_TIME
dhcp-option=3,$STATIC_IP      # Gateway
dhcp-option=6,$STATIC_IP      # DNS (mesmo IP do servidor)
log-queries
log-dhcp
EOF

echo "[+] Reiniciando dnsmasq..."
systemctl restart dnsmasq
systemctl enable dnsmasq

echo "[✓] Servidor DHCP configurado e em execução na interface $INTERFACE"
echo "[i] Faixa de IPs: $DHCP_RANGE_START - $DHCP_RANGE_END"
echo "[i] Gateway/DNS: $STATIC_IP"
