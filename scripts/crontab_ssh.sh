#!/bin/bash

echo "Adicionando crontab do root para atualização do OpenSSH no boot..."

# Comando a ser adicionado
CRON_CMD="@reboot /usr/bin/apt-get update && /usr/bin/apt-get install -y openssh-server"

# Verifica se já existe no crontab do root
if ! sudo crontab -l 2>/dev/null | grep -q 'openssh-server'; then
    (sudo crontab -l 2>/dev/null; echo "$CRON_CMD") | sudo crontab -
    echo "Crontab adicionado com sucesso."
else
    echo "Crontab já contém o comando."
fi
