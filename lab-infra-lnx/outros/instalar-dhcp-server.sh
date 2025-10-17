#!/bin/bash

set -e

# Caminhos
DHCP_CONF="/etc/dhcp/dhcpd.conf"
ISC_DHCP_CONF="/etc/default/isc-dhcp-server"

echo " Backup do script atual..."
cp "$(realpath "$0")" "$(realpath "$0").bak"

echo " Verificando e instalando isc-dhcp-server..."
if ! dpkg -s isc-dhcp-server &>/dev/null; then
    apt update && apt install -y isc-dhcp-server bind9 bind9-utils bind9-doc dnsutils
else
    echo " isc-dhcp-server já está instalado."
fi

tsig-keygen -a hmac-sha256 dhcpupdate > /etc/bind/dhcpupdate.key
TSIG_SECRET=$(grep -oP 'secret "\K[^"]+' /etc/bind/dhcpupdate.key)
chown root:bind /etc/bind/dhcpupdate.key
chown root:bind /etc/bind/dhcpupdate.key

echo " Aplicando nova configuração ao $ISC_DHCP_CONF..."
cp "$ISC_DHCP_CONF" "$ISC_DHCP_CONF.bak"

cat > "$ISC_DHCP_CONF" <<EOF
INTERFACESv4="eth0"
EOF

echo " Aplicando nova configuração ao $DHCP_CONF..."
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
  range 192.168.100.150 192.168.100.200;
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

host rocky-n1 {
    hardware ethernet 00:11:22:33:44:55;
    fixed-address 192.168.100.11;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.100.1, 192.168.100.2;
}

host rocky-n2 {
    hardware ethernet 00:11:22:33:44:56;
    fixed-address 192.168.100.12;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.100.1, 192.168.100.2;
}

host rocky-n3 {
    hardware ethernet 00:11:22:33:44:57;
    fixed-address 192.168.100.13;
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

host firewall {
    hardware ethernet 08:00:27:AA:00:01;
    fixed-address 192.168.100.254;
    option domain-name "infraopen.com";
    option domain-search "infraopen.com";
    option domain-name-servers 192.168.100.1, 192.168.100.2;
}
EOF

echo " Reiniciando serviço DHCP..."
systemctl restart isc-dhcp-server

echo " Configuração DHCP finalizada com sucesso!"