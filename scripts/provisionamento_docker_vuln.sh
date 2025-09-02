#!/bin/bash

# Este script consolida todas as etapas de provisionamento de um nó Vagrant
# para o ambiente de laboratório de segurança.

# --- Ajustar Placa de REDE ---
echo "Configurando a placa de rede com IP 10.10.10.102..."
cp /etc/network/interfaces /etc/network/interfaces.bak || true
cat << 'EONET' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
address 10.10.10.102
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
sudo ./ssh_user_config.sh

# --- Agendar Atualização do SSH via Crontab ---
echo "Adicionando crontab para atualização do SSH..."
sudo ./crontab_ssh.sh

# --- Instalação do Docker ---
echo "Iniciando o provisionamento e instalação do Docker..."
bash docker_provision.sh
sudo apt install docker-compose

# --- Download e UP dos Containers Vulneraveis prontos ---
echo "Iniciando o deploy dos containers de ferramentas e aplicações vulneráveis..."
cd /home/vagrant/lab-sec/scripts/
bash up_all_containers_vuln.sh

# --- Download e Build dos Containers Vulneraveis - NODEGOAT ---
cd /home/vagrant/lab-sec/docker-vuln-NodeGoat/
chmod u+x *.sh
sudo ./setup.sh

# --- Download e Build dos Containers Vulneraveis - SECURITYSHEPERD ---
cd /home/vagrant/lab-sec/docker-vuln-Securityshepherd/
chmod u+x *.sh
sudo ./setup.sh

# --- Download e Build dos Containers Vulneraveis - crAPI---
cd /home/vagrant/lab-sec/docker-vuln-crAPI/
chmod u+x *.sh
sudo ./setup.sh

# --- Download e Build dos Containers Vulneraveis - FLASKAPP---
cd /home/vagrant/lab-sec/docker-vuln-Flask_App/
chmod u+x *.sh
sudo ./setup.sh

# --- Ajustar Teclado ---
echo "Ajustando o layout do teclado..."
cd /home/vagrant/lab-sec/scripts
sudo ./ajuste_teclado.sh

# --- Listar Portas dos Containers ---
echo "Listando portas dos containers para referência..."
bash listar-container-portas.sh

# --- Mensagem Final ---
echo "Exibindo mensagem final..."
bash msg_final.sh 10.10.10.102

echo "Provisionamento do nó concluído!"
