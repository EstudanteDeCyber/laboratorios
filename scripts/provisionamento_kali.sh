#!/bin/bash
# Este script automatiza o provisionamento de um ambiente Kali Linux.

echo "Atualizando o Sistema"
# Nao atualiza ssh e ajusta para atualizacao sem iteracao
export DEBIAN_FRONTEND=noninteractive
sudo apt update
# Nao atualiza ssh e ajusta para atualizacao sem iteracao
#apt-mark hold openssh-server
#NEEDRESTART_MODE=a apt -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" upgrade
#DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --fix-broken install -y || true
sudo apt-get --fix-broken install -y || true
sudo dpkg --configure -a || true
sudo apt-get install -f -y || true
sudo apt-get upgrade -y || true
sudo apt autoremove -y
echo

# Diretório para scripts
echo "Criando diretório para scripts..."
mkdir -p /tmp/scripts
cd /tmp/scripts
echo

# --- Download dos Scripts do GitHub ---
echo "Baixando scripts do GitHub..."
echo
# Usando um loop para baixar os arquivos de forma mais eficiente
SCRIPTS_TO_DOWNLOAD=(
  "ajuste_teclado.sh"
  "ssh_user_config.sh"
  "msg_final.sh"
  "crontab_ssh.sh"
  "docker_provision_kali.sh"
)

for script in "${SCRIPTS_TO_DOWNLOAD[@]}"; do
  wget -O "$script" "https://raw.githubusercontent.com/EstudanteDeCyber/lab-sec/main/scripts/$script"
done
echo

# Dar permissão de execução
echo "Concedendo permissões de execução..."
chmod u+x *.sh
echo

# --- Execução dos Scripts Baixados ---
echo "Executando scripts de provisionamento..."
echo
echo "Rodando script de ajustes de SSH e USUÁRIOS..."
sudo ./ssh_user_config.sh
echo
echo "Rodando script de Ajuste de Teclado..."
#sudo ./ajuste_teclado.sh
echo
echo "Rodando script de Ajuste de Contrab..."
sudo ./crontab_ssh.sh
echo
echo "Rodando script de Instalaxao do docker..."
sudo ./docker_provision_kali.sh
echo

# Lista de vms deployadas com o Vagrant
cat << 'VMS' > /root/redes.sh
for ip in 20 30 40 50 101 102; do ping -c 1 -w 1 10.10.10."$ip" | grep ttl; done
VMS
mv /root/redes.sh /usr/bin/redes.sh && chmod 755 /usr/bin/redes.sh
cd /home/vagrant & ln -s /usr/bin/redes.sh redes.sh

# Lista de apps e portas Vulneraveis
cat << TOOLS > lista_tools.sh
ssh vagrant@10.10.10.101 "bash lab-sec/scripts/listar-container-portas.sh"
TOOLS
chown vagrant:vagrant && chmod u+x lista_tools.sh
# Lista de apps e portas Vulneraveis
cat << VULN> lista_vulb.sh
ssh vagrant@10.10.10.102 "bash lab-sec/scripts/listar-container-portas.sh"
VULN
chown vagrant:vagrant && chmod u+x lista_vuln.sh

# --- Ajustar Placa de Rede ---
echo "Ajustando a configuração da rede..."
cp /etc/network/interfaces /etc/network/interfaces.bak || true
cat << 'EONET' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
address 10.10.10.10
netmask 255.255.255.0

auto eth2
iface eth2 inet static
address 192.168.56.10
netmask 255.255.255.0
EONET

echo "Clonando repositorios"

# Clonando repos Git
cd /home/vagrant
sudo git clone https://github.com/brunobotelhobr/My-Tools.git
cd My-Tools && sudo git clone https://github.com/brunobotelhobr/My-IP-Calculator.git

#cloudgoat
cd /home/vagrant/
sudo docker pull rhinosecuritylabs/cloudgoat:latest

cat << 'CLOUDGOAT' > /home/vagrant/readme_cloudgoat
# Rodar o container (Voce ja cairá dentro dele)
sudo docker run -it rhinosecuritylabs/cloudgoat:latest
# Exemplo de como listar os laboratórios disponíveis
cloudgoat list
CLOUDGOAT

#vulnLabs
sudo git clone --depth 1 https://github.com/vulhub/vulhub

# Cloudfoxable 
git clone https://github.com/BishopFox/cloudfoxable.git
cd cloudfoxable
sudo docker build --no-cache -t cloudfoxable .

cat << 'CLOUDFOXABLE' > /home/vagrant/readme_cloudgoat
# Rodar o container (Voce ja cairá dentro dele)
sudo docker run -it -v cloudfoxable
# Exemplo de como listar os laboratórios disponíveis
cloudgoat list
CLOUDFOXABLE

sudo chown vagrant:vagrant /home/vagrant/*

# --- Mensagem Final ---
bash /tmp/scripts/msg_final.sh 10.10.10.10
echo "Configurações concluídas !!!"
