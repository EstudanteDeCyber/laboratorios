#!/bin/bash

# Caminhos padrão
BIND_DIR="/etc/bind"
BIND_CONF="$BIND_DIR/named.conf.local"

# IP do master
MASTER_IP="192.168.100.1"

echo "Configurando rede no dns3..."
cp /etc/network/interfaces /etc/network/interfaces.bak || true
cat > /etc/network/interfaces <<EONET
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.100.2
    netmask 255.255.255.0
    gateway 192.168.100.254
    dns-nameservers 192.168.100.1 192.168.100.2
    search infraopen.com
EONET

echo " Verificando e instalando BIND9..."
if ! dpkg -s isc-dhcp-server &>/dev/null; then
    apt update && apt install -y bind9 bind9-utils bind9-doc dnsutils
else
    echo " BIND9 já está instalado."
fi

echo " Backup do arquivo original..."
cp "$BIND_CONF" "$BIND_CONF.bak"

echo "️ Configurando named.conf.local para servidor SLAVE..."

cat > "$BIND_CONF" <<EOF
zone "infraopen.com" {
    type slave;
    masters { $MASTER_IP; };
    file "/var/cache/bind/db.infraopen.com";
};

zone "100.168.192.in-addr.arpa" {
    type slave;
    masters { $MASTER_IP; };
    file "/var/cache/bind/db.100.168.192";
};
EOF

echo " Permissões padrão para cache..."
# O diretório /var/cache/bind já tem as permissões corretas por padrão
chown bind:bind /var/cache/bind
chmod 755 /var/cache/bind

	  cat > /etc/resolv.conf <<LOL
search infraopen.com
nameserver 192.168.100.1
nameserver 192.168.100.2
LOL

echo " Reiniciando o serviço BIND9..."
systemctl restart bind9

echo " Servidor DNS Slave (dns2) configurado com sucesso."
