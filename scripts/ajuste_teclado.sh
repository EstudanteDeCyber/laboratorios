#!/bin/bash

# Ajuste de Teclado - Configuração para layout brasileiro (ABNT2) em sistemas Debian

export DEBIAN_FRONTEND=noninteractive
echo 'keyboard-configuration keyboard-configuration/layoutcode select br' | debconf-set-selections
echo 'keyboard-configuration keyboard-configuration/modelcode select abnt2' | debconf-set-selections
echo 'keyboard-configuration keyboard-configuration/variantcode select' | debconf-set-selections
sudo NEEDRESTART_MODE=a apt-get -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" install keyboard-configuration console-setup console-data
sudo pkg-reconfigure -f noninteractive keyboard-configuration
sudo etupcon --force
sudo loadkeys br-abnt2 || loadkeys br || echo "Layout de teclado não encontrado"
