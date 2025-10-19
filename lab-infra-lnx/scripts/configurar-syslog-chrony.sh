#!/bin/bash

# Definir o servidor syslog
SYSLOG_SERVER="syslog.infraopen.com"
SYSLOG_PORT=514
SYSLOG_PROTOCOL="udp"

# Definir o servidor NTP
NTP_SERVER="ntp.infraopen.com"

# Função para verificar erros
check_error() {
  if [ $? -ne 0 ]; then
    echo "Erro: $1"
    exit 1
  fi
}

echo "Atualizando pacotes e instalando rsyslog e chrony..."
sudo apt-get update -y && sudo apt-get install -y rsyslog chrony
check_error "Falha ao instalar rsyslog ou chrony."

# Configurar rsyslog com filtro mais seletivo
echo "Configurando rsyslog para envio seletivo ao servidor $SYSLOG_SERVER..."
CONF_LINE="*.info;mail.none;authpriv.none;cron.none"
if [ "$SYSLOG_PROTOCOL" == "tcp" ]; then
  echo "$CONF_LINE @@$SYSLOG_SERVER:$SYSLOG_PORT" | sudo tee -a /etc/rsyslog.conf
else
  echo "$CONF_LINE @$SYSLOG_SERVER:$SYSLOG_PORT" | sudo tee -a /etc/rsyslog.conf
fi
check_error "Falha ao configurar rsyslog."

# Reiniciar rsyslog
echo "Reiniciando o rsyslog..."
sudo systemctl restart rsyslog
check_error "Falha ao reiniciar rsyslog."

# Verificar o status do rsyslog
echo "Verificando status do rsyslog..."
sudo systemctl status rsyslog | grep "Active:"
check_error "Serviço rsyslog não está ativo."

# Configurar chrony para sincronizar com o servidor NTP
echo "Configurando chrony para sincronizar com $NTP_SERVER..."
sudo sed -i '/^server /d' /etc/chrony/chrony.conf
echo "server $NTP_SERVER iburst" | sudo tee -a /etc/chrony/chrony.conf
check_error "Falha ao configurar chrony."

# Reiniciar o chrony para aplicar as configurações
echo "Reiniciando o chrony..."
sudo systemctl restart chrony
check_error "Falha ao reiniciar o chrony."

# Verificar o status do chrony
echo "Verificando status do chrony..."
sudo systemctl status chrony | grep "Active:"
check_error "Serviço chrony não está ativo."

# Forçar sincronização inicial do NTP
echo "Forçando sincronização inicial do NTP..."
sudo chronyc makestep
check_error "Falha ao forçar sincronização do NTP."

# Verificar fontes de sincronização do chrony
echo "Verificando fontes de sincronização do chrony..."
sudo chronyc sources
check_error "Falha ao verificar fontes do chrony."

echo "Configuração concluída com sucesso!"