#!/bin/bash

# Criação do usuário hugom
if ! id -u hugom >/dev/null 2>&1; then
  useradd -m -s /bin/bash hugom
  echo "hugom:change-me" | chpasswd
  usermod -aG sudo hugom
  echo "root:p@ssw0rd" | chpasswd
  cp /etc/skel/.bashrc /home/hugom/
  cp /etc/skel/.profile /home/hugom/
  chown hugom:hugom /home/hugom/.bashrc /home/hugom/.profile
fi