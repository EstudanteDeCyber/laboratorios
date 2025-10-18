#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
echo 'keyboard-configuration keyboard-configuration/layoutcode select br' | debconf-set-selections
echo 'keyboard-configuration keyboard-configuration/modelcode select abnt2' | debconf-set-selections
echo 'keyboard-configuration keyboard-configuration/variantcode select' | debconf-set-selections

NEEDRESTART_MODE=a apt-get -y install keyboard-configuration console-setup console-data
dpkg-reconfigure -f noninteractive keyboard-configuration
setupcon --force
loadkeys br-abnt2 || loadkeys br || echo " Layout de teclado não encontrado"
