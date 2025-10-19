#!/bin/bash

set -e

# Diretórios e arquivos
BIND_DIR="/etc/bind"
BIND_CONF="$BIND_DIR/named.conf.local"
OPTIONS_CONF="$BIND_DIR/named.conf.options"
ZONE_DIR="/var/lib/bind"
CACHE_DIR="/var/cache/bind"
ZONE_ARQUIVO="$ZONE_DIR/db.infraopen.com"
ZONE_REV_ARQUIVO="$ZONE_DIR/db.100.168.192"

DHCP_CONF="/etc/dhcp/dhcpd.conf"
ISC_DHCP_CONF="/etc/default/isc-dhcp-server"
TSIG_KEY_FILE="$BIND_DIR/dhcpupdate.key"

echo "Configurando rede no dns1..."
cp /etc/network/interfaces /etc/network/interfaces.bak || true
cat > /etc/network/interfaces <<EONET
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.100.1
    netmask 255.255.255.0
    gateway 192.168.100.254
    dns-nameservers 192.168.100.1 192.168.100.2
    search infraopen.com
EONET

echo "📦 Instalando pacotes necessários..."
apt update && apt install -y isc-dhcp-server bind9 bind9-utils bind9-doc dnsutils

echo "📁 Criando diretórios do BIND..."
mkdir -p "$ZONE_DIR" "$CACHE_DIR"
chown bind:bind "$ZONE_DIR" "$CACHE_DIR"

echo "🔐 Gerando chave TSIG..."
tsig-keygen -a hmac-sha256 dhcpupdate > "$TSIG_KEY_FILE"
chown root:bind "$TSIG_KEY_FILE"
TSIG_SECRET=$(grep -oP 'secret "\K[^"]+' "$TSIG_KEY_FILE")

echo "📦 Backup deste script..."
cp "$(realpath "$0")" "$(realpath "$0").bak"

########################################
# 🛠️ Configuração do BIND9
########################################

echo "🔧 Configurando BIND9..."

cp "$BIND_CONF" "$BIND_CONF.bak"

cat > "$BIND_CONF" <<EOF
key dhcpupdate {
    algorithm hmac-sha256;
    secret "$TSIG_SECRET";
};

zone "infraopen.com" {
    type master;
    file "$ZONE_ARQUIVO";
    allow-update { key dhcpupdate; };
};

zone "100.168.192.in-addr.arpa" {
    type master;
    file "$ZONE_REV_ARQUIVO";
    allow-update { key dhcpupdate; };
};
EOF

# named.conf.options pode ser atualizado aqui se necessário

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
cluster-n1 		IN      A       192.168.100.21
cluster-n2 		IN      A       192.168.100.22
cluster-n3 		IN      A       192.168.100.23
samba			IN		A		192.168.100.155
sftp          	IN      CNAME   samba.infraopen.com.
webserver		IN		A		192.168.100.150
webmin         	IN      CNAME   webserver.infraopen.com.
syslog			IN		A		192.168.100.151
ntp				IN		CNAME	syslog.infraopen.com.
firewall 		IN      A       192.168.100.254
EOF

# Zona reversa
echo "🧾 Criando zona direta..."
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
21      IN      PTR     debian-n1.infraopen.com.
22      IN      PTR     debian-n2.infraopen.com.
23      IN      PTR     debian-n3.infraopen.com.
100     IN      PTR     samba.infraopen.com.
150     IN      PTR     webserver.infraopen.com.
151     IN      PTR     syslog.infraopen.com.
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

########################################
# 🛠️ Configuração do DHCP Server
########################################

echo "🔧 Configurando DHCP Server..."

cp "$ISC_DHCP_CONF" "$ISC_DHCP_CONF.bak"
cat > "$ISC_DHCP_CONF" <<EOF
INTERFACESv4="eth0"
EOF

cp "$DHCP_CONF" "$DHCP_CONF.bak"
cat > "$DHCP_CONF" <<EOF
ddns-update-style interim;

key dhcpupdate {
    algorithm hmac-sha256;
    secret "$TSIG_SECRET";
}

zone infraopen.com. {
    primary 127.0.0.1;
    key dhcpupdate;
}

zone 100.168.192.in-addr.arpa. {
    primary 127.0.0.1;
    key dhcpupdate;
}

subnet 192.168.100.0 netmask 255.255.255.0 {
  range 192.168.100.180 192.168.100.200;
  option routers 192.168.100.254;
  option domain-name-servers 192.168.100.1, 192.168.100.2;
  option domain-name "infraopen.com";
  option domain-search "infraopen.com";
  default-lease-time 600;
  max-lease-time 7200;
}

host dns1 {
    hardware ethernet 08:00:27:BB:00:01;
    fixed-address 192.168.100.1;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.100.1, 192.168.100.2;
}

host dns2 {
    hardware ethernet 08:00:27:BB:00:02;
    fixed-address 192.168.100.2;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.100.1, 192.168.100.2;
}

host samba1 {
    hardware ethernet 08:00:27:BB:00:03;
    fixed-address 192.168.100.100;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.100.1, 192.168.100.2;
}

host webserver{
    hardware ethernet 08:00:27:BB:00:04;
    fixed-address 192.168.100.150;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.100.1, 192.168.100.2;
}

host syslog {
    hardware ethernet 08:00:27:BB:00:05;
    fixed-address 192.168.100.151;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.100.1, 192.168.100.2;
}

host debian-n1 {
    hardware ethernet 00:11:22:33:44:58;
    fixed-address 192.168.100.21;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.100.1, 192.168.100.2;
}

host debian-n2 {
    hardware ethernet 00:11:22:33:44:59;
    fixed-address 192.168.100.22;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.1.1, 192.168.100.2;
}

host debian-n3 {
    hardware ethernet 00:11:22:33:44:60;
    fixed-address 192.168.100.23;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.100.1, 192.168.100.2;
}

host win10 {
    hardware ethernet 08:00:27:BB:DD:E2;
    fixed-address 192.168.100.200;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.100.1, 192.168.100.2;
}

host firewall {
    hardware ethernet 08:00:27:AA:00:01;
    fixed-address 192.168.100.254;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.100.1, 192.168.100.2;
}
EOF

echo "✅ Configuração concluída com sucesso."