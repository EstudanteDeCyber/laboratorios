#!/bin/bash

# Start cron
cron

# Start Apache
service apache2 start

# Aguarda o banco ser criado e aplica permissões (loop com timeout de segurança)
echo "Aguardando criação do banco de dados..."
for i in {1..10}; do
    if [ -f /home/www-data/waf2py_community/applications/Waf2Py/databases/waf2py.sqlite ]; then
        echo "Banco encontrado. Ajustando permissões..."
        chown www-data:www-data /home/www-data/waf2py_community/applications/Waf2Py/databases/waf2py.sqlite
        chmod u+rw /home/www-data/waf2py_community/applications/Waf2Py/databases/waf2py.sqlite
        break
    fi
    sleep 3
done

# Mantém o container ativo
tail -f /dev/null

