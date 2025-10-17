#!/bin/bash

set -e

# Caminhos padrão
BIND_DIR="/etc/bind"
BIND_CONF="$BIND_DIR/named.conf.local"
OPTIONS_CONF="$BIND_DIR/named.conf.options"
ZONE_DIR="/var/lib/bind"
CACHE_DIR="/var/cache/bind"
ZONE_ARQUIVO="$ZONE_DIR/db.infraopen.com"
ZONE_REV_ARQUIVO="$ZONE_DIR/db.100.168.192"

mkdir -p "$ZONE_DIR"
mkdir -p "$CACHE_DIR"
chown bind:bind "$ZONE_DIR"
chown bind:bind "$CACHE_DIR"

echo " Verificando e instalando BIND9..."
if ! dpkg -s isc-dhcp-server &>/dev/null; then
    apt update && apt install -y bind9 bind9-utils bind9-doc dnsutils
else
    echo " BIND9 já está instalado."
fi

# Backup do script original
cp "$(realpath "$0")" "$(realpath "$0").bak"

TSIG_SECRET=$(grep -oP 'secret "\K[^"]+' /etc/bind/dhcpupdate.key)

echo "🛠️ Atualizando configuração do BIND9..."

# Backup da config
cp "$BIND_CONF" "$BIND_CONF.bak"

# Atualiza named.conf.local
cat > "$BIND_CONF" <<EOF
key dhcpupdate {
    algorithm hmac-sha256;
    secret "$TSIG_SECRET";
};

zone "infraopen.com" {
    type master;
    file "$ZONE_DIR/db.infraopen.com";
    allow-update { key dhcpupdate; };
    allow-transfer { 192.168.100.2; };
    also-notify { 192.168.100.2; };
};

zone "100.168.192.in-addr.arpa" {
    type master;
    file "$ZONE_DIR/db.100.168.192";
    allow-update { key dhcpupdate; };
    allow-transfer { 192.168.100.2; };
    also-notify { 192.168.100.2; };
};
EOF

# Backup da config
cp "$OPTIONS_CONF" "$OPTIONS_CONF.bak"

# Atualiza named.conf.options
cat > "$OPTIONS_CONF" <<EOF
options {
	directory "/var/cache/bind";
    forwarders {
        192.168.100.254;
    };
    allow-recursion { 192.168.100.0/24; };
    recursion yes;
    dnssec-validation auto;
};
EOF


# Zona direta
cat > "$ZONE_ARQUIVO" << EOF
\$TTL    604800
@       IN      SOA     dns1.infraopen.com. admin.infraopen.com. (
                     2025072901 ; Serial (YYYYMMDDnn)
                     3600       ; Refresh
                     1800       ; Retry
                     1209600    ; Expire
                     86400 )    ; Negative Cache TTL

@       		IN      NS      dns1.infraopen.com.
@       		IN      NS      dns2.infraopen.com.
infraopen.com	IN		A		192.168.100.0
dns1    		IN      A       192.168.100.1
dns2    		IN      A       192.168.100.2
rocky-n1 		IN      A       192.168.100.11
rocky-n2 		IN      A       192.168.100.12
rocky-n3 		IN      A       192.168.100.13
debian-n1 		IN      A       192.168.100.21
debian-n2 		IN      A       192.168.100.22
debian-n3 		IN      A       192.168.100.23
webserver		IN		A		192.168.100.150
ntp				IN		A		192.168.100.151
samba1			IN		A		192.168.100.152
firewall 		IN      A       192.168.100.254
EOF

# Zona reversa
cat > "$ZONE_REV_ARQUIVO" << EOF
\$TTL    604800
@       IN      SOA     dns1.infraopen.com. admin.infraopen.com. (
                     2025072901 ; Serial (YYYYMMDDnn)
                     3600       ; Refresh
                     1800       ; Retry
                     1209600    ; Expire
                     86400 )    ; Negative Cache TTL

        IN      NS      dns1.infraopen.com.
		IN      NS      dns2.infraopen.com.
0		IN		PTR		infraopen.com
1       IN      PTR     dns1.infraopen.com.
2       IN      PTR     dns2.infraopen.com.
11      IN      PTR     rocky-n1.infraopen.com.
12      IN      PTR     rocky-n2.infraopen.com.
13      IN      PTR     rocky-n3.infraopen.com.
21      IN      PTR     debian-n1.infraopen.com.
22      IN      PTR     debian-n2.infraopen.com.
23      IN      PTR     debian-n3.infraopen.com.
150     IN      PTR     webserver.infraopen.com.
151     IN      PTR     ntp.infraopen.com.
152     IN      PTR     samba1.infraopen.com.
200     IN      PTR     win10.infraopen.com.
254     IN      PTR     firewall.infraopen.com.
EOF

# Permissões
chown bind:bind "$ZONE_DIR"/db.*
chmod 640 "$ZONE_DIR"/db.*

	  cat > /etc/resolv.conf <<LOL
search infraopen.com
nameserver 192.168.100.1
nameserver 192.168.100.2
LOL

# Verificação de sintaxe
echo "### Verificando configurações do Bind..."
named-checkconf || { echo "Erro de sintaxe no named.conf"; exit 1; }

# Reiniciar serviço
systemctl daemon-reload
echo "### Reiniciando Bind9..."
systemctl restart bind9 || { echo "Erro ao reiniciar Bind9."; exit 1; }
systemctl enable bind9

# Status
echo "### Status do Bind9:"
systemctl status bind9

echo "✅ Configuração finalizada com sucesso."
