#!/bin/bash
# Adiciona 'set -e' para que o script pare em caso de erro
set -e

echo "Instalando dependências necessárias (sshpass)..."
# Atualiza a lista de pacotes e instala o sshpass
# Manteremos o sshpass aqui caso precise dele para outra automação no futuro
apt-get update
apt-get install -y sshpass

# Instalação do script de firewall e service unit
echo "Copiando e configurando firewall..."

cp /tmp/scripts/firewall.sh /etc/firewall.sh
cp /tmp/scripts/firewall.service /etc/systemd/system/firewall.service
chmod 700 /etc/firewall.sh

# Configuração de rede
echo "Configurando rede..."

cp /etc/network/interfaces /etc/network/interfaces.bak || true

cat > /etc/network/interfaces <<EONET
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 10.0.2.15
    netmask 255.255.255.0
    gateway 10.0.2.2
    dns-nameservers 10.0.2.3

auto eth1
iface eth1 inet static
    address 192.168.100.254
    netmask 255.255.255.0
    dns-nameservers 10.0.2.3 192.168.100.1 192.168.100.2
    search infraopen.com

auto eth2
iface eth2 inet static
    address 192.168.56.10
    netmask 255.255.255.0
EONET

# Configura resolv.conf
cat > /etc/resolv.conf <<NET
search infraopen.com
nameserver 192.168.100.1
nameserver 192.168.100.2
NET

# Habilita firewall para proximo boot
systemctl enable firewall.service

echo "Setup da firewall finalizado com sucesso! A chave foi gerada e está pronta para ser usada pelas outras VMs."