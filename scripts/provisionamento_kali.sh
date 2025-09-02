#!/bin/bash

# Este script automatiza o provisionamento de um ambiente Kali Linux.

# Diretório para scripts temporários
echo "Criando diretório para scripts..."
mkdir -p /tmp/scripts
cd /tmp/scripts

# --- Download dos Scripts do GitHub ---
echo "Baixando scripts do GitHub..."

# Usando um loop para baixar os arquivos de forma mais eficiente
SCRIPTS_TO_DOWNLOAD=(
  "ajuste_teclado.sh"
  "ssh_user_config.sh"
  "msg_final.sh"
)

for script in "${SCRIPTS_TO_DOWNLOAD[@]}"; do
  wget -O "$script" "https://raw.githubusercontent.com/EstudanteDeCyber/lab-sec/main/scripts/$script"
done

# Dar permissão de execução
echo "Concedendo permissões de execução..."
chmod u+x *.sh

# --- Execução dos Scripts Baixados ---
echo "Executando scripts de provisionamento..."

# Executa os scripts um a um. A ordem é importante.
sudo ./ssh_user_config.sh
sudo ./ajuste_teclado.sh

# Clonando repos Git
cd /home/vagrant
git clone https://github.com/brunobotelhobr/My-Tools.git
cd My-Tools && git clone https://github.com/brunobotelhobr/My-IP-Calculator.git

# Lista de vms deployadas com o Vagrant
cat << 'VMS' > /root/redes.sh
for ip in 20 30 40 50 101 102; do ping -c 1 -w 1 10.10.10."$ip" | grep ttl; done
VMS
mv /root/redes.sh /usr/bin/redes.sh && chmod 755 /usr/bin/redes.sh
ln -s /usr/bin/redes.sh redes

# Lista de apps e portas Vulneraveis
cat << 'APPS' > /home/vagrant/lista_de_apps
##################################################################
##   Aplicacoes Disponiveis abaixo. Divirta-se sem moderacao!!  ##
##   Tire um pint e acesse-as pelo KALI                         ##
##################################################################

extremely_vulnerable_flask_app      https://10.0.2.15:5000- -> 80
crapi-web                           https://10.0.2.15:8888- -> 80
crapi-web                           https://10.0.2.15:8443- -> 443
mailhog                             https://10.0.2.15:8025- -> 8025
secshep_tomcat                      https://10.0.2.15:80- -> 8080
secshep_tomcat                      https://10.0.2.15:443- -> 8443
secshep_mariadb                     https://10.0.2.15:3306- -> 3306
secshep_mongo                       https://10.0.2.15:27017- -> 27017
nodegoat-web-1                      https://10.0.2.15:4000- -> 4000
citizenstignowasp                   https://10.0.2.15:8081- -> 80
citizenstignowasp                   https://10.0.2.15:3308- -> 3306
WrongSecrets                        https://10.0.2.15:2000- -> 8080
WebGoat                             https://10.0.2.15:9090- -> 9090
WebGoat                             https://10.0.2.15:8084- -> 8080
vulnlab                             https://10.0.2.15:1337- -> 80
appsecco_dsvw                       https://10.0.2.15:8085- -> 8000
badstore                            https://10.0.2.15:8083- -> 80
hackazon                            https://10.0.2.15:8089- -> 80
juice-shop                          https://10.0.2.15:3000- -> 30100
bWAPP                               https://10.0.2.15:8082- -> 80
bWAPP                               https://10.0.2.15:3309- -> 3306
zap-webswing                        https://10.0.2.15:2222- -> 8080
zap-webswing                        https://10.0.2.15:3333- -> 8990
citizenstigdvwa                     https://10.0.2.15:8080- -> 80
citizenstigdvwa                     https://10.0.2.15:3307- -> 3306
mailhog                             (porta interna: 1025)
crapi-workshop                      (sem portas expostas)
crapi-community                     (porta interna: 6060)
crapi-identity                      (porta interna: 10001)
api.mypremiumdealership.com         (porta interna: 443)
mongodb                             (porta interna: 27017)
postgresdb                          (porta interna: 5432)
nodegoat-mongo-1                    (porta interna: 27017)
juice-shop                          (porta interna: 3000)
APPS

# Ajustar a permissao para a lista de apps
chmod 755 /home/vagrant/lista_apps

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

# Clonando repos Git
cd /home/vagrant
sudo git clone https://github.com/brunobotelhobr/My-Tools.git
cd My-Tools && sudo it clone https://github.com/brunobotelhobr/My-IP-Calculator.git

#cloudgoat
sudo apt-get install docker.io
sudo systemctl enable docker && sudo systemctl start docker
sudo usermod -aG sudo vagrant
sudo docker pull rhinosecuritylabs/cloudgoat:latest

cat << 'CLOUDGOAT' > /home/vagrant/readme_cloudgoat
# Rodar o container (Voce ja cairá dentro dele)
sudo docker run -it rhinosecuritylabs/cloudgoat:latest
# Exemplo de como listar os laboratórios disponíveis
cloudgoat list
CLOUDGOAT

#vulnLabs

sudo git clone --depth 1 https://github.com/vulhub/vulhub

sudo chown vagrant:vagrant /home/vagrant/*

# --- Mensagem Final ---
echo "Exibindo mensagem final..."
bash /tmp/scripts/msg_final.sh 10.10.10.10
echo "Configurações concluídas !!!"
