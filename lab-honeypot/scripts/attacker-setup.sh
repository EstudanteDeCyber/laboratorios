#!/usr/bin/env bash
# provisioning/attacker-setup.sh
# Script simples de provisionamento para a VM atacante (debian). Instala pacotes úteis.
set -euo pipefail

echo "==> Instalando ferramentas úteis (nmap, curl, socat, netcat, python3-pip, jq, hping3)..."
sudo apt-get install -y nmap curl socat netcat-openbsd python3-pip jq hping3 tcpdump

#echo "==> Instalando metasploit-framework (opcional, dependendo da box Kali pode já vir instalado)..."
#if ! command -v msfconsole >/dev/null 2>&1; then
#  sudo apt-get install -y metasploit-framework || true
#fi
#
#echo "==> Ajustes e utilitários Python..."
#sudo pip3 install requests urllib3

# ===============================================================
# SSH Config
# ===============================================================
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^PubkeyAuthentication yes/#PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
echo "vagrant:vagrant" | chpasswd

# ===============================================================
# Ajustar Placa de REDE para o IP específico
# ===============================================================
cp /etc/network/interfaces /etc/network/interfaces.bak || true
cat << 'EONET' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
address 192.168.56.15
netmask 255.255.255.0
EONET

echo "==> Atacante pronto. Exemplos de uso:"
echo " - nmap -sS -p 1-65535 <IP_TPOT>"
echo " - curl http://<IP_TPOT>/"
echo " - ssh <IP_TPOT> -p 22  (se o honeypot oferecer)"
echo " - tcpdump -i any 'port 80 or port 22'"

echo "Fim do provisioning attacker."
