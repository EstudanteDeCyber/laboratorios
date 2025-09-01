#!/bin/bash

# Este script consolida todas as etapas de provisionamento de um nó Vagrant
# para o ambiente de laboratório de segurança.

# --- Ajustar Placa de REDE ---
echo "Configurando a placa de rede com IP 10.10.10.101..."
cp /etc/network/interfaces /etc/network/interfaces.bak || true
cat << 'EONET' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
address 10.10.10.101
netmask 255.255.255.0
EONET

# --- Instalação do Git ---
echo "Instalando o git..."
sudo apt update
sudo apt install -y git

# --- Clonagem do Repositório ---
echo "Clonando o repositório lab-sec..."
# Navega para o diretório /home/vagrant antes de clonar
cd /home/vagrant/
git clone https://github.com/EstudanteDeCyber/lab-sec.git

# --- Ajustes de User Vagrant e SSH ---
echo "Configurando usuário e SSH..."
cd /home/vagrant/lab-sec/scripts
chmod u+x *
bash ssh_user_config.sh

# --- Agendar Atualização do SSH via Crontab ---
echo "Adicionando crontab para atualização do SSH..."
# Use um comando mais robusto para crontab
(crontab -l 2>/dev/null | grep -v 'openssh-server'; echo "@reboot apt-get update && apt-get install -y openssh-server") | crontab -

# --- Instalação do Docker ---
echo "Iniciando o provisionamento e instalação do Docker..."
bash docker_provision.sh

# --- Download e UP dos Containers/Ferramentas ---
echo "Iniciando o deploy dos containers de ferramentas ..."

# Horusec
echo "Configurando Horusec..."
cd /home/vagrant/lab-sec/horusec
chmod u+x setup.sh && bash setup.sh

# HashiCorp Vault
echo "Configurando HashiCorp Vault..."
cd /home/vagrant/lab-sec/docker-tools-hashicorp_vault/
chmod u+x setup.sh && sudo bash setup.sh
sudo chmod 644 /var/services/vault/userconfig/tls/vault.key

# Todos os outros containers (Docker-Tools)
echo "Subindo todos os outros containers..."
cd /home/vagrant/lab-sec/scripts
bash up_all_containers_tools.sh

# DefectDojo
echo "Configurando DefectDojo..."
cd /home/vagrant/lab-sec/docker-tools-django-DefectDojo
chmod u+x setup.sh && bash setup.sh

# --- Ajustar Teclado ---
echo "Ajustando o layout do teclado..."
cd /home/vagrant/lab-sec/scripts
bash ajuste_teclado.sh

# --- Listar Portas dos Containers ---
echo "Listando portas dos containers para referência..."
bash listar-container-portas.sh

# --- Mensagem Final ---
echo "Exibindo mensagem final..."
bash msg_final.sh 10.10.10.101

echo "Provisionamento do nó concluído!"
