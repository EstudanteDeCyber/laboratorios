#!/bin/bash

# Este script instala e configura um ambiente LAMP (Linux, Apache, MariaDB, PHP)
# de forma não interativa no Debian 12 (Bookworm).
# Ele define a senha do root do MariaDB e remove o usuário 'debian-sys-maint'.

# --- Configurações Iniciais ---
#MARIADB_ROOT_PASSWORD="your_strong_password" # <<< MUDE ESTA SENHA!
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-$(openssl rand -base64 12)}" # Gera senha aleatória se não definida

# --- Atualizar o sistema ---
echo "--- Atualizando a lista de pacotes e pacotes do sistema ---"
apt update -y
NEEDRESTART_MODE=a apt upgrade -y # Atualiza pacotes sem pedir interação para reinicialização

# --- Instalar Apache ---
echo "--- Instalando Apache2 ---"
apt install -y apache2

# --- Instalar MariaDB (MySQL) ---
echo "--- Instalando MariaDB-server e client ---"
apt install -y mariadb-server mariadb-client

# --- Aguardar o MariaDB iniciar completamente ---
echo "--- Aguardando o serviço MariaDB iniciar ---"
until systemctl is-active mariadb; do
  echo "MariaDB ainda não está ativo. Tentando novamente em 5 segundos..."
  sleep 5
done
echo "MariaDB está ativo!"

# --- Executar mysql_upgrade para garantir a integridade das tabelas do sistema ---
# Isso é crucial para evitar o erro "View 'mysql.user' references invalid table(s)"
echo "--- Executando mysql_upgrade para corrigir e atualizar tabelas do sistema ---"
mysql_upgrade -u root # O root do sistema pode acessar o MariaDB root via unix_socket

# --- Configurar a senha do root do MariaDB e remover usuários e bancos de dados inseguros ---
echo "--- Configurando a senha do root do MariaDB e aplicando configurações de segurança ---"

# Alterar a senha do root. Usamos ALTER USER que é o método recomendado.
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';"

# Remover usuários anônimos
mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='';"

# Remover acesso remoto do root (opcional, pode ser 'NO' se precisar de acesso remoto para desenvolvimento)
mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"

# Remover o banco de dados 'test'
mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS test;"
mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"

# Recarregar privilégios para que as mudanças tenham efeito
mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

# --- Instalar PHP e módulos comuns ---
echo "--- Instalando PHP e módulos PHP para Apache e MySQL ---"
apt install -y php libapache2-mod-php php-mysql php-cli php-json php-common php-mbstring php-xml php-zip php-gd php-curl

# --- Configurar Apache para PHP (Opcional: Pode ajustar mais tarde se precisar) ---
echo "--- Configurando Apache para PHP ---"

# Ativar o Módulo mod_rewrite
a2enmod rewrite
# Configurar AllowOverride para .htaccess
# sed -i '/<Directory \/var\/www\/html\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/sites-available/000-default.conf

# Exemplo para aumentar o limite de upload e memória
# sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' /etc/php/8.2/apache2/php.ini
# sed -i 's/^post_max_size = .*/post_max_size = 64M/' /etc/php/8.2/apache2/php.ini
# sed -i 's/^memory_limit = .*/memory_limit = 256M/' /etc/php/8.2/apache2/php.ini
# systemctl restart apache2

# Priorizar index.php sobre index.html
sed -i 's/DirectoryIndex index.html index.cgi index.pl index.php/DirectoryIndex index.php index.html index.cgi index.pl/' /etc/apache2/mods-enabled/dir.conf

# Reiniciar Apache para aplicar as mudanças
echo "--- Reiniciando Apache2 ---"
systemctl restart apache2

# --- Criar uma página de teste PHP (opcional) ---
echo "--- Criando arquivo info.php para teste ---"
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

# --- Ajustar permissões para a pasta web (opcional, para desenvolvimento) ---
echo "--- Ajustando permissões da pasta web ---"
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

echo "--- Instalação LAMP concluída! ---"
echo "Acesse o Apache em http://sua_ip_da_vm/"
echo "Acesse a página de informações do PHP em http://sua_ip_da_vm/info.php"
echo "Lembre-se de deletar 'info.php' em ambientes de produção por segurança."
echo "Senha do root do MariaDB: ${MARIADB_ROOT_PASSWORD}"