#!/bin/bash

# Script de instalação e configuração do Samba para uso com Vagrant

# Exit on error
set -e

# Função para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Verifica se o script está sendo executado como root
if [[ $EUID -ne 0 ]]; then
    log "ERRO: Este script deve ser executado como root"
    exit 1
fi

# Definir variáveis
SAMBA_USER="sambauser"
SAMBA_GROUP="smbshare"
SAMBA_PASSWORD="${SAMBA_PASSWORD:-$(openssl rand -base64 12)}" # Gera senha aleatória se não definida
PUBLIC_DIR="/public"
PRIVATE_DIR="/private"
SMB_CONF="/etc/samba/smb.conf"

log "Iniciando configuração do Samba..."

# Atualiza pacotes e instala dependências
log "Atualizando pacotes e instalando dependências..."
export DEBIAN_FRONTEND=noninteractive
if ! apt update -y; then
    log "ERRO: Falha ao atualizar pacotes"
    exit 1
fi
if ! apt install -y samba smbclient cifs-utils; then
    log "ERRO: Falha ao instalar pacotes do Samba"
    exit 1
fi

# Faz backup do smb.conf, se existir
if [[ -f "$SMB_CONF" ]]; then
    log "Fazendo backup do arquivo $SMB_CONF..."
    cp "$SMB_CONF" "${SMB_CONF}.bak-$(date '+%Y%m%d%H%M%S')"
fi

# Configuração do Samba: Definindo configurações globais
log "Configurando o arquivo $SMB_CONF..."
cat > "$SMB_CONF" << EOF
[global]
   workgroup = WORKGROUP
   server string = Samba Server %v
   netbios name = debian12-samba
   security = user
   map to guest = bad user
   dns proxy = no
   server min protocol = SMB2
   server max protocol = SMB3
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
EOF

# Cria os diretórios para compartilhamento, se não existirem
log "Criando diretórios de compartilhamento..."
for dir in "$PUBLIC_DIR" "$PRIVATE_DIR"; do
    if [[ ! -d "$dir" ]]; then
        if ! mkdir -p "$dir"; then
            log "ERRO: Falha ao criar diretório $dir"
            exit 1
        fi
    fi
done

# Cria o grupo smbshare, se não existir
if ! getent group "$SAMBA_GROUP" > /dev/null; then
    log "Criando grupo $SAMBA_GROUP..."
    if ! groupadd "$SAMBA_GROUP"; then
        log "ERRO: Falha ao criar grupo $SAMBA_GROUP"
        exit 1
    fi
fi

# Define permissões dos diretórios
log "Configurando permissões dos diretórios..."
if ! chmod 2775 "$PUBLIC_DIR" || ! chmod 2770 "$PRIVATE_DIR"; then
    log "ERRO: Falha ao configurar permissões dos diretórios"
    exit 1
fi
if ! chown root:"$SAMBA_GROUP" "$PUBLIC_DIR" "$PRIVATE_DIR"; then
    log "ERRO: Falha ao configurar dono dos diretórios"
    exit 1
fi

# Configura o compartilhamento público
log "Configurando compartilhamento público..."
cat >> "$SMB_CONF" << EOF

[public]
   comment = Public Folder
   path = $PUBLIC_DIR
   writable = yes
   guest ok = yes
   guest only = yes
   force create mode = 0775
   force directory mode = 0775
EOF

# Configura o compartilhamento privado
log "Configurando compartilhamento privado..."
cat >> "$SMB_CONF" << EOF

[private]
   comment = Private Folder
   path = $PRIVATE_DIR
   writable = yes
   guest ok = no
   valid users = @$SAMBA_GROUP
   force create mode = 0770
   force directory mode = 0770
   inherit permissions = yes
EOF

# Cria o usuário sambauser, se não existir
if ! id "$SAMBA_USER" > /dev/null 2>&1; then
    log "Criando usuário $SAMBA_USER..."
    if ! useradd -M -s /sbin/nologin "$SAMBA_USER"; then
        log "ERRO: Falha ao criar usuário $SAMBA_USER"
        exit 1
    fi
fi

# Adiciona o usuário ao grupo smbshare
log "Adicionando $SAMBA_USER ao grupo $SAMBA_GROUP..."
if ! usermod -aG "$SAMBA_GROUP" "$SAMBA_USER"; then
    log "ERRO: Falha ao adicionar $SAMBA_USER ao grupo $SAMBA_GROUP"
    exit 1
fi

# Define a senha do usuário Samba
log "Definindo senha para o usuário $SAMBA_USER..."
if ! printf "%s\n%s\n" "$SAMBA_PASSWORD" "$SAMBA_PASSWORD" | smbpasswd -s -a "$SAMBA_USER"; then
    log "ERRO: Falha ao definir senha para $SAMBA_USER"
    exit 1
fi
if ! smbpasswd -e "$SAMBA_USER"; then
    log "ERRO: Falha ao habilitar usuário $SAMBA_USER"
    exit 1
fi

# Verifica a configuração do Samba
log "Verificando configuração do Samba..."
if ! testparm -s; then
    log "ERRO: Configuração do Samba inválida"
    exit 1
fi

# Reinicia os serviços do Samba
log "Reiniciando serviços do Samba..."
if ! systemctl restart smbd nmbd; then
    log "ERRO: Falha ao reiniciar serviços do Samba"
    exit 1
fi

# Verifica se os serviços estão ativos
log "Verificando status dos serviços..."
for service in smbd nmbd; do
    if ! systemctl is-active --quiet "$service"; then
        log "ERRO: Serviço $service não está ativo"
        exit 1
    fi
done

# Testa os compartilhamentos
log "Testando compartilhamentos..."
if ! smbclient -L localhost -N; then
    log "ERRO: Falha ao listar compartilhamentos"
    exit 1
fi

log "Configuração do Samba concluída com sucesso!"
log "Usuário: $SAMBA_USER"
log "Senha: $SAMBA_PASSWORD"
log "Compartilhamentos configurados: $PUBLIC_DIR (público), $PRIVATE_DIR (privado)"
log "Teste com smbclient //localhost/$PUBLIC_DIR e smbclient //localhost/$PRIVATE_DIR -U $SAMBA_USER"