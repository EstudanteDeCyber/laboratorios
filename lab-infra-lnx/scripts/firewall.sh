#!/bin/bash
# chmod +x /etc/firewall.sh

HOST_IP="192.168.56.1"
LAN_SUBNET="192.168.100.0/24"
NTP_SERVERS=("a.st1.ntp.br" "b.st1.ntp.br" "c.st1.ntp.br" "d.st1.ntp.br")
WEB_IP="192.168.100.150"
NTP_IP="192.168.100.151"
SMB_IP="192.168.100.152"
RDP_PORT="2000"
WINDOWS_IP="192.168.100.200"


# Limpar regras existentes
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Políticas temporárias abertas durante configuração
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Permitir conexões já estabelecidas e relacionadas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ICMP (ping)
iptables -A INPUT -p icmp -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT

# Roteamento ativado
echo 1 > /proc/sys/net/ipv4/ip_forward

# NAT para saída da LAN (eth1) para internet (eth0)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Permitir comunicação entre VMs na LAN
iptables -A FORWARD -i eth1 -o eth1 -j ACCEPT

# Saída da interface host-only (eth2)
iptables -A OUTPUT -o eth2 -j ACCEPT

# SSH (somente do host)
iptables -A INPUT -i eth2 -s $HOST_IP -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth2 -d $HOST_IP -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j DROP

# NTP
for NTP_SERVER in "${NTP_SERVERS[@]}"; do
  iptables -A OUTPUT -p udp -d $NTP_SERVER --dport 123 -s $NTP_IP -j ACCEPT
  iptables -A INPUT  -p udp -s $NTP_SERVER --sport 123 -d $NTP_IP -j ACCEPT
done

# DNS
iptables -A INPUT  -p udp --dport 53 -s $LAN_SUBNET -j ACCEPT
iptables -A INPUT  -p tcp --dport 53 -s $LAN_SUBNET -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -d 0.0.0.0/0 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -d 0.0.0.0/0 -j ACCEPT

# DNAT: redirecionar host (192.168.29.1) para webserver
iptables -t nat -A PREROUTING -i eth2 -s $HOST_IP -p tcp --dport 80 -j DNAT --to-destination $WEB_IP:80

# FORWARD para tráfego do host até o webserver
iptables -A FORWARD -i eth2 -o eth1 -p tcp -d $WEB_IP --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth1 -o eth2 -p tcp -s $WEB_IP --sport 80 -m state --state ESTABLISHED,RELATED -j ACCEPT

# Masquerade de saída para o webserver
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

# *** Redirecionar RDP (porta 2000) do firewall para o servidor Windows ***
# Redireciona tráfego de RDP (porta 2000 no firewall) para o servidor Windows (porta 3389)
iptables -t nat -A PREROUTING -i eth2 -s $HOST_IP -p tcp --dport $RDP_PORT -j DNAT --to-destination $WINDOWS_IP:3389

# *** Permitir tráfego de entrada na porta 2000 do firewall ***
# Permitir acesso ao RDP na porta 2000 do firewall (somente do host)
iptables -A FORWARD -i eth2 -o eth1 -p tcp -d $WINDOWS_IP --dport 3389 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth1 -o eth2 -p tcp -s $WINDOWS_IP --sport 3389 -m state --state ESTABLISHED,RELATED -j ACCEPT

# *** Permitir retorno do servidor Windows para o host (resposta) ***
# Permitir tráfego de retorno do servidor Windows para o host
iptables -A FORWARD -i eth1 -o eth2 -p tcp -s $WINDOWS_IP --sport 3389 -d $HOST_IP -m state --state ESTABLISHED,RELATED -j ACCEPT

# Redirecionar (DNAT) tráfego do host para o servidor Samba interno
iptables -t nat -A PREROUTING -i eth2 -s $HOST_IP -p udp --dport 137 -j DNAT --to-destination $SMB_IP:137
iptables -t nat -A PREROUTING -i eth2 -s $HOST_IP -p udp --dport 138 -j DNAT --to-destination $SMB_IP:138
iptables -t nat -A PREROUTING -i eth2 -s $HOST_IP -p tcp --dport 139 -j DNAT --to-destination $SMB_IP:139
iptables -t nat -A PREROUTING -i eth2 -s $HOST_IP -p tcp --dport 445 -j DNAT --to-destination $SMB_IP:445

# Permitir encaminhamento do host para o servidor Samba (entrada)
iptables -A FORWARD -i eth2 -o eth1 -p udp -s $HOST_IP -d $SMB_IP --dport 137 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -p udp -s $HOST_IP -d $SMB_IP --dport 138 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -p tcp -s $HOST_IP -d $SMB_IP --dport 139 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -p tcp -s $HOST_IP -d $SMB_IP --dport 445 -m state --state NEW,ESTABLISHED -j ACCEPT

# Permitir retorno do servidor Samba para o host (resposta)
iptables -A FORWARD -i eth1 -o eth2 -p udp -s $SMB_IP -d $HOST_IP --sport 137 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i eth1 -o eth2 -p udp -s $SMB_IP -d $HOST_IP --sport 138 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i eth1 -o eth2 -p tcp -s $SMB_IP -d $HOST_IP --sport 139 -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i eth1 -o eth2 -p tcp -s $SMB_IP -d $HOST_IP --sport 445 -m state --state ESTABLISHED,RELATED -j ACCEPT

# Mascarar IP de origem como o do firewall (se necessário)
iptables -t nat -A POSTROUTING -o eth1 -d $SMB_IP -p udp --dport 137 -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth1 -d $SMB_IP -p udp --dport 138 -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth1 -d $SMB_IP -p tcp --dport 139 -j MASQUERADE
iptables -t nat -A POSTROUTING -o eth1 -d $SMB_IP -p tcp --dport 445 -j MASQUERADE

# Políticas restritivas no final
iptables -P INPUT DROP
iptables -P FORWARD DROP

# Persistir regras
apt install -y iptables-persistent
netfilter-persistent save
systemctl enable netfilter-persistent
systemctl start netfilter-persistent

cp /tmp/script/firewall.service /etc/systemd/system/firewall.service

echo "✅ Firewall configurado com sucesso!"