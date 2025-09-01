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
  "docker_provision_kali.sh"
  "ajuste_teclado.sh"
  "burp_container.sh"
  "install_burpsuite_container.sh"
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
bash docker_provision_kali.sh
sudo ./ajuste_teclado.sh
bash install_burpsuite_container.sh

# Move o script do burp_container para o diretório do usuário 'vagrant'
echo "Movendo burp_container.sh para o diretório do usuário vagrant..."
mv burp_container.sh /home/vagrant/
chown vagrant:vagrant /home/vagrant/burp_container.sh

# --- Clonagem de Repositórios Git ---
echo "Clonando repositórios Git..."

# Navega para o diretório do usuário 'vagrant' para clonar os repositórios
# Isso garante que os arquivos não fiquem em /tmp/scripts
cd /home/vagrant/
git clone https://github.com/brunobotelhobr/My-Tools.git
cd My-Tools && git clone https://github.com/brunobotelhobr/My-IP-Calculator.git

# --- Criação de Arquivos de Script e Lista de Apps ---
echo "Criando arquivos de scripts e lista de apps..."

# Criar o script de rede
cat << 'EONET' > /root/redes.sh
for ip in 20 30 40 50 101 102; do ping -c 1 -w 1 10.10.10."$ip" | grep ttl; done
EONET
mv /root/redes.sh /usr/bin/redes.sh && chmod 755 /usr/bin/redes.sh
ln -s /usr/bin/redes.sh redes

# Criar a lista de apps
cat << 'EONET' > /home/vagrant/lista_apps
Docker-Tools: ################################################################
Docker-Tools: ## Aplicacoes Disponivies abaixo. Divirta-se sem moderacao!!
Docker-Tools: ##                   Tire um pint e acesse-as pelo KALI
Docker-Tools: ################################################################
Docker-Tools:
Docker-Tools: crapi-web                       http://10.10.10.101:8888- -> 80
Docker-Tools: crapi-web                       http://10.10.10.101:8443- -> 443
Docker-Tools: mailhog                         http://10.10.10.101:8025- -> 8025
Docker-Tools: zap-webswing                    http://10.10.10.101:2222- -> 8080
Docker-Tools: zap-webswing                    http://10.10.10.101:3333- -> 8990
Docker-Tools: hackazon                        http://10.10.10.101:8089- -> 80
Docker-Tools: appsecco_dsvw                   http://10.10.10.101:8085- -> 8000
Docker-Tools: WebGoat                         http://10.10.10.101:9090- -> 9090
Docker-Tools: WebGoat                         http://10.10.10.101:8084- -> 8080
Docker-Tools: badstore                        http://10.10.10.101:8083- -> 80
Docker-Tools: bWAPP                          http://10.10.10.101:8082- -> 80
Docker-Tools: citizenstignowasp               http://10.10.10.101:8081- -> 80
Docker-Tools: citizenstignowasp               http://10.10.10.101:3308- -> 3306
Docker-Tools: citizenstigdvwa                 http://10.10.10.101:8080- -> 80
Docker-Tools: citizenstigdvwa                 http://10.10.10.101:3307- -> 3306
Docker-Tools: vulnlab                         http://10.10.10.101:1337- -> 80
Docker-Tools: bWAPP                          (porta interna: 3306)
Docker-Tools: mailhog                         (porta interna: 1025)
Docker-Tools: crapi-workshop                  (sem portas expostas)
Docker-Tools: crapi-community                 (porta interna: 6060)
Docker-Tools: crapi-identity                  (porta interna: 10001)
Docker-Tools: postgresdb                      (porta interna: 5432)
Docker-Tools: api.mypremiumdealership.com     (porta interna: 443)
Docker-Tools: mongodb                         (porta interna: 27017)
Docker-Vuln: ################################################################
Docker-Vuln: ## Aplicacoes Disponivies abaixo. Divirta-se sem moderacao!!
Docker-Vuln: ##                   Tire um pint e acesse-as pelo KALI
Docker-Vuln: ################################################################
Docker-Vuln:
Docker-Vuln: secshep_tomcat                   http://10.10.10.102:80- -> 8080
Docker-Vuln: secshep_tomcat                   http://10.10.10.102:443- -> 8443
Docker-Vuln: secshep_mongo                    http://10.10.10.102:27017- -> 27017
Docker-Vuln: secshep_mariadb                  http://10.10.10.102:3306- -> 3306
Docker-Vuln: extremely_vulnerable_flask_app   http://10.10.10.102:5000- -> 80
Docker-Vuln: nodegoat_web_1                   http://10.10.10.102:4000- -> 4000
Docker-Vuln: juice-shop                      http://10.10.10.102:3000- -> 30100
Docker-Vuln: WrongSecrets                    http://10.10.10.102:2000- -> 8080
Docker-Vuln: nodegoat_mongo_1                 (porta interna: 27017)
Docker-Vuln: juice-shop                      (porta interna: 3000)
EONET

# Ajustar a permissão para a lista de apps
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

# --- Mensagem Final ---
echo "Exibindo mensagem final..."
bash /tmp/scripts/msg_final.sh 10.10.10.10
echo "Configurações concluídas !!!"
