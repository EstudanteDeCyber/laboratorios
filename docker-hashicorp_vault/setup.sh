#!/bin/bash

# Script de Preparação do Host para Vault com TLS
# Data: $(date)
# Descrição: Prepara o ambiente host para execução do Vault

set -e  # Para o script em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se está rodando como root ou com sudo
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script precisa ser executado como root ou com sudo"
        exit 1
    fi
}

# Verificar dependências
check_dependencies() {
    log_info "Verificando dependências..."
    
    # Verificar se openssl está instalado
    if ! command -v openssl &> /dev/null; then
        log_error "OpenSSL não está instalado. Por favor, instale o OpenSSL primeiro."
        exit 1
    fi
    
    log_success "Todas as dependências estão instaladas"
}

# 1. Preparando o Ambiente
setup_directories() {
    log_info "Criando estrutura de diretórios..."
    
    # Criar diretórios
    mkdir -p /var/services/vault/{audit,config,data,file,logs,userconfig/tls,plugins}
    
    # Alterar permissões
    sudo chown -R 100:100 /var/services/vault/
    
    log_success "Estrutura de diretórios criada com sucesso"
    
    # Mostrar estrutura criada
    log_info "Estrutura de diretórios:"
    tree /var/services/vault/ 2>/dev/null || find /var/services/vault/ -type d | sed 's/[^-][^\/]*\//  /g;s/^  //'
}

# 2. Criando Certificados TLS
generate_certificates() {
    log_info "Gerando certificados TLS..."
    
    # Navegar para o diretório temporário
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # 2.1. Gerando a Chave Privada
    log_info "Gerando chave privada RSA..."
    openssl genpkey -algorithm RSA -out private.key
    
    # 2.2. Gerando a Solicitação de Assinatura de Certificado (CSR)
    log_info "Gerando CSR (Certificate Signing Request)..."
    openssl req -new -key private.key -out request.csr \
        -subj "/C=BR/ST=Sampa/L=Sao Paulo/O=LABSEC/OU=IT/CN=labsec.com.br/emailAddress=admin@labsec.com.br" \
        -reqexts SAN -extensions SAN \
        -config <(echo "[req]";
                  echo "[req_distinguished_name]";
                  echo "countryName = Country Name (2 letter code)";
                  echo "countryName_default = BR";
                  echo "stateOrProvinceName = State or Province Name (full name)";
                  echo "stateOrProvinceName_default = Sampa";
                  echo "localityName = Locality Name (eg, city)";
                  echo "localityName_default = Sao Paulo";
                  echo "organizationName = Organization Name (eg, company)";
                  echo "organizationName_default = LABSEC";
                  echo "organizationalUnitName = Organizational Unit Name (eg, section)";
                  echo "organizationalUnitName_default = IT";
                  echo "commonName = Common Name (e.g. server FQDN or YOUR name)";
                  echo "commonName_default = labsec.com.br";
                  echo "emailAddress = Email Address";
                  echo "emailAddress_default = admin@labsec.com.br";
                  echo "[SAN]";
                  echo "subjectAltName=DNS:vault.test.lan,DNS:127.0.0.1")
    
    # 2.3. Assinando o Certificado
    log_info "Assinando o certificado..."
    openssl x509 -req -in request.csr -signkey private.key -out certificate.crt -days 365 \
        -extfile <(echo "[SAN]"; echo "subjectAltName=DNS:vault.test.lan,DNS:127.0.0.1")
    
    # 2.4. Movendo e Renomeando os Arquivos
    log_info "Movendo certificados para diretório de configuração..."
    cp certificate.crt ca.crt
    cp ca.crt /var/services/vault/userconfig/tls/ca.crt
    cp certificate.crt /var/services/vault/userconfig/tls/vault.crt
    cp private.key /var/services/vault/userconfig/tls/vault.key
    
    # Limpar diretório temporário
    cd /
    rm -rf "$TEMP_DIR"
    
    log_success "Certificados TLS gerados e instalados com sucesso"
}

# 3. Criando o arquivo de configuração do Vault
create_vault_config() {
    log_info "Criando arquivo de configuração do Vault..."
    
    cat > /var/services/vault/config/vault-config.hcl << 'EOF'
disable_cache       = true
disable_mlock       = true
ui                  = true
max_lease_ttl       = "2h"
default_lease_ttl   = "20m"
raw_storage_endpoint = "true"
disable_printable_check = "true"
cluster_addr        = "https://vault.test.lan:8201"
api_addr            = "https://vault.test.lan"

listener "tcp" {
  address                   = "0.0.0.0:8200"
  tls_disable               = false
  tls_client_ca_file        = "/vault/userconfig/tls/ca.crt"
  tls_cert_file             = "/vault/userconfig/tls/vault.crt"
  tls_key_file              = "/vault/userconfig/tls/vault.key"
  tls_disable_client_certs  = "true"
}

storage "raft" {
  node_id  = "vault-1"
  path     = "/vault/data"
}
EOF
    
    log_success "Arquivo de configuração vault-config.hcl criado"
}

# 4. Mostrar informações finais
show_final_info() {
    log_info "=============================================="
    log_success "PREPARAÇÃO DO HOST CONCLUÍDA COM SUCESSO!"
    log_info "=============================================="
    echo
    log_info "Ambiente preparado para execução do Vault:"
    echo -e "  📁 Diretórios criados em: ${GREEN}/var/services/vault/${NC}"
    echo -e "  🔐 Certificados TLS configurados"
    echo -e "  ⚙️  Arquivo de configuração criado"
    echo
    log_info "Estrutura de diretórios criada:"
    tree /var/services/vault/ 2>/dev/null || find /var/services/vault/ -type d | sed 's/[^-][^\/]*\//  /g;s/^  //'
    echo
    log_warning "PRÓXIMOS PASSOS:"
    echo -e "  1. ${YELLOW}Execute o Docker Compose separadamente${NC}"
    echo -e "  2. ${YELLOW}Inicialize o Vault após o container estar rodando${NC}"
    echo -e "  3. ${YELLOW}Configure as chaves de unsealing${NC}"
}

# Função principal
main() {
    log_info "Iniciando preparação do host para Vault..."
    echo
    
    # Verificar privilégios
    check_privileges
    
    # Verificar dependências
    check_dependencies
    
    # 1. Preparar ambiente
    setup_directories
    
    # 2. Gerar certificados TLS
    generate_certificates
    
    # 3. Criar configuração do Vault
    create_vault_config
    
    # 4. Mostrar informações finais
    show_final_info
}

# Executar função principal
main "$@"
