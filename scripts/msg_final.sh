#!/bin/bash

# Script para exibir a mensagem final LINUX

# Captura o endereço IP da máquina
IP=$(hostname -I | awk '{print $1}')

echo "###########################################################"
echo "##                                                       ##"
echo "##      Tire um print dos ips :))                        ##"
echo "##                                                       ##"
echo "##                                                       ##"
echo "##         ***** VM IP: $IP ******             ##"
echo "##                                                       ##"
echo "##                                                       ##"
echo "##    VM -->> user: vagrant   password: vagrant          ##"
echo "##    VM -->> user: root      password: vagrant          ##"
echo "##                                                       ##"
echo "###########################################################"
echo
sleep 15
