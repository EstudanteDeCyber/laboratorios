#!/bin/bash

# Ajuste de Teclado - Layout brasileiro (ABNT2) sem interação
echo "Ajustando de Teclado - Layout brasileiro (ABNT2)"

set -e  # Encerra o script em caso de erro

export DEBIAN_FRONTEND=noninteractive

# Define as opções do teclado via debconf
echo 'keyboard-configuration keyboard-configuration/layout select Brazil' | debconf-set-selections
echo 'keyboard-configuration keyboard-configuration/layoutcode select br' | debconf-set-selections
echo 'keyboard-configuration keyboard-configuration/variant select' | debconf-set-selections
echo 'keyboard-configuration keyboard-configuration/model select Generic 105-key PC (intl.)' | debconf-set-selections
echo 'keyboard-configuration keyboard-configuration/modelcode select pc105' | debconf-set-selections
echo 'keyboard-configuration keyboard-configuration/optionscode string' | debconf-set-selections
echo 'keyboard-configuration keyboard-configuration/store_defaults_in_debconf_db boolean true' | debconf-set-selections

# Instala pacotes relacionados ao teclado e console sem interação
apt-get update -qq
apt-get install -y -qq \
    keyboard-configuration \
    console-setup \
    console-data

# Reconfigura o teclado sem interação
dpkg-reconfigure -f noninteractive keyboard-configuration

# Aplica configuração no console
setupcon --force

# Aplica layout de teclado no modo texto
loadkeys br-abnt2 || loadkeys br || echo "Layout de teclado não encontrado"
