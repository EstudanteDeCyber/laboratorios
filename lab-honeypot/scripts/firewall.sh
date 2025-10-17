#!/bin/bash

# Script para configurar um firewall com iptables para o laboratório T-Pot
# Assumindo:
# - Interfaces: eth0 (WAN/192.168.56.254), eth1 (DMZ/192.168.50.1), eth2 (LAN/20.20.20.10)
# - Honeypot ports: 22,80,443,3389 (WAN -> DMZ)
# - SIEM port: 5044 (DMZ -> LAN para logs)
# - Admin ports: 
#   - Firewall: 22,80,443 na WAN (192.168.56.254)
#   - T-Pot: 22,64297 (LAN -> DMZ; opcional WAN para 64297)
# - Habilitar NAT para LAN e DMZ acessarem a Internet
# - Executar como root

# Verificar se rodando como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root (sudo $0)"
  exit 1
fi

# Definir redes
DMZ_IF="eth1"
LAN_IF="eth2"
WAN_IF="eth4"
WAN_IP="192.168.56.254/24"
DMZ_NET="192.168.50.0/24"
LAN_NET="20.20.20.0/24"

## Configurar IP estático na WAN
#ip addr flush dev $WAN_IF
#ip addr add $WAN_IP dev $WAN_IF
#ip link set $WAN_IF up

# Habilitar IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Limpar regras existentes
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Configurar NAT para LAN e DMZ sairem via WAN
iptables -t nat -A POSTROUTING -o $WAN_IF -s $LAN_NET -j MASQUERADE
iptables -t nat -A POSTROUTING -o $WAN_IF -s $DMZ_NET -j MASQUERADE

# Regras de FORWARD (tráfego entre redes)

# 1. Permitir WAN -> DMZ para honeypot ports (22,80,443,3389)
for port in 22 80 443 3389; do
  iptables -A FORWARD -i $WAN_IF -o $DMZ_IF -p tcp --dport $port -j ACCEPT
done

# 2. Permitir DMZ -> LAN para SIEM logs (porta 5044)
iptables -A FORWARD -i $DMZ_IF -o $LAN_IF -p tcp --dport 5044 -j ACCEPT

# 3. Bloquear todo outro tráfego DMZ -> LAN
iptables -A FORWARD -i $DMZ_IF -o $LAN_IF -j DROP

# 4. Permitir LAN -> DMZ para admin (SSH 22 e T-Pot WebUI 64297)
for port in 22 64297; do
  iptables -A FORWARD -i $LAN_IF -o $DMZ_IF -p tcp --dport $port -j ACCEPT
done

# 5. Permitir LAN -> WAN (acesso à Internet)
iptables -A FORWARD -i $LAN_IF -o $WAN_IF -j ACCEPT

# 6. Permitir respostas de tráfego estabelecido
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Regras de INPUT (tráfego para o próprio firewall)

# Permitir SSH, HTTP, HTTPS na WAN (192.168.56.254) para administração do firewall
for port in 22 80 443; do
  iptables -A INPUT -i $WAN_IF -p tcp -d $WAN_IP --dport $port -j ACCEPT
done

# Opcional: Permitir acesso ao T-Pot WebUI (64297) via WAN (descomente se necessário)
# iptables -A FORWARD -i $WAN_IF -o $DMZ_IF -p tcp --dport 64297 -j ACCEPT

# Permitir tráfego loopback
iptables -A INPUT -i lo -j ACCEPT

# Permitir respostas estabelecidas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Bloquear o resto no INPUT
iptables -A INPUT -j DROP

# Salvar regras (para Debian/Ubuntu; ajuste para sua distro)
iptables-save > /etc/iptables.rules

echo "Regras iptables configuradas com sucesso!"
echo "IP WAN configurado: $WAN_IP"
echo "Para restaurar: iptables-restore < /etc/iptables.rules"
echo "Certifique-se de configurar IPs nas interfaces DMZ ($DMZ_IF: 192.168.50.1/24) e LAN ($LAN_IF: 20.20.20.10/24) manualmente."