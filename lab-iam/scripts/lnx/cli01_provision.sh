#!/bin/bash

# Atualiza o sistema
sudo apt update && sudo apt upgrade -y

# Instala um navegador web (Firefox)
sudo apt install -y firefox

# Instala ferramentas de rede básicas
sudo apt install -y iputils-ping net-tools dnsutils

# Adiciona entradas no /etc/hosts para facilitar o acesso
sudo tee -a /etc/hosts <<EOF
10.10.10.30 idp01
10.10.10.31 app01
EOF

# Mensagem de conclusão
echo "Provisionamento da CLI01 concluído. Você pode acessar o navegador e as ferramentas de rede."


