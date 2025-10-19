#!/bin/bash
# Ajustar SSH e USUARIOS
echo
echo "Ajustando SSH e USUÁRIOS..."
echo
sudo sed -i 's/^#*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh
echo "vagrant:vagrant" | chpasswd
echo "root:vagrant" | chpasswd
