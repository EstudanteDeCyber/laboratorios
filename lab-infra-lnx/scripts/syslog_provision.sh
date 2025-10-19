#!/bin/bash

# ============================
# Script de configuração do servidor Syslog central
# ============================

set -e

# Atualizar pacotes e instalar rsyslog e SSH
echo "[+] Atualizando pacotes e instalando rsyslog..."
export DEBIAN_FRONTEND=noninteractive
apt update -y && apt install -y rsyslog openssh-server

# Verificar e criar usuário syslog e grupo adm, se necessário
echo "[+] Verificando usuário syslog e grupo adm..."
if ! id -u syslog >/dev/null 2>&1; then
    echo "[+] Usuário syslog não existe. Criando..."
    useradd -r -s /bin/false -d /nonexistent syslog
fi

if ! getent group adm >/dev/null 2>&1; then
    echo "[+] Grupo adm não existe. Criando..."
    groupadd adm
fi

# Criar diretório para logs remotos
echo "[+] Criando diretório para logs remotos..."
mkdir -p /var/log/remote
chown syslog:adm /var/log/remote
if [ $? -ne 0 ]; then
    echo "[!] Erro ao definir permissões para /var/log/remote. Continuando..."
else
    echo "[+] Permissões definidas para /var/log/remote (syslog:adm)."
fi
chmod 750 /var/log/remote

# Criar configuração rsyslog específica para recebimento de logs remotos
echo "[+] Configurando recebimento de logs em /etc/rsyslog.d/10-remote.conf..."
cat > /etc/rsyslog.d/10-remote.conf << 'EOF'
# Habilitar recepção de logs remotos
module(load="imudp")    # Para UDP
input(type="imudp" port="514")

module(load="imtcp")    # Para TCP
input(type="imtcp" port="514")

# Template para armazenar logs organizadamente
template(name="RemoteLogs" type="string"
         string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")

# Aplicar template a todos os logs recebidos
*.* ?RemoteLogs

# Evitar duplicação em arquivos locais
& ~
EOF

# (Opcional) Configuração de TLS, se certificados estiverem presentes
if [ -d "/etc/rsyslog.d/cert" ]; then
  echo "[+] Configurando TLS para recebimento seguro..."
  cat >> /etc/rsyslog.d/10-remote.conf << 'EOF'

# TLS para TCP porta 10514
$DefaultNetstreamDriver gtls
$DefaultNetstreamDriverCAFile /etc/rsyslog.d/cert/ca.pem
$DefaultNetstreamDriverCertFile /etc/rsyslog.d/cert/server.cert.pem
$DefaultNetstreamDriverKeyFile /etc/rsyslog.d/cert/server.key.pem

$InputTCPServerStreamDriverAuthMode x509/name
$InputTCPServerStreamDriverPermittedPeer *
$InputTCPServerStreamDriverMode 1
$InputTCPServerRun 10514
EOF
fi

# Configurar logrotate para os logs remotos
echo "[+] Criando configuração de logrotate em /etc/logrotate.d/rsyslog-remote..."
cat > /etc/logrotate.d/rsyslog-remote << 'EOF'
/var/log/remote/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 syslog adm
    sharedscripts
    postrotate
        /usr/bin/systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF

# Reiniciar rsyslog para aplicar tudo
echo "[+] Reiniciando rsyslog..."
systemctl restart rsyslog

# Verificar status do rsyslog
echo "[+] Status do rsyslog:"
systemctl is-active --quiet rsyslog && echo "✅ rsyslog está ativo." || echo "❌ rsyslog falhou ao iniciar."