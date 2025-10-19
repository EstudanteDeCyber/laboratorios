#!/bin/bash

# Este script instala e configura o Chrony para sincronizar com os servidores NTP.br.
# Ele foi projetado para ser executado sem interação em sistemas Debian/Ubuntu.

# Verifica se o script está sendo executado como root
if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root. Use sudo."
  exit 1
fi

echo "Iniciando a instalação e configuração do Chrony..."

# 1. Atualiza a lista de pacotes
echo "Atualizando a lista de pacotes..."
apt-get update -y

# 2. Instala o Chrony
echo "Instalando o Chrony..."
apt-get install chrony -y

# 3. Faz um backup do arquivo de configuração original do Chrony
echo "Fazendo backup do arquivo de configuração original..."
mv /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak

# 4. Cria o novo arquivo de configuração do Chrony
echo "Criando o novo arquivo de configuração /etc/chrony/chrony.conf..."
cat <<EOF > /etc/chrony/chrony.conf
# Servidores públicos do NTP.br com NTS disponível
server a.st1.ntp.br iburst nts
server b.st1.ntp.br iburst nts
server c.st1.ntp.br iburst nts
server d.st1.ntp.br iburst nts
server gps.ntp.br iburst nts

# Arquivo usado para manter a informação do atraso do seu relógio local
driftfile /var/lib/chrony/chrony.drift

# Local para as chaves e cookies NTS
ntsdumpdir /var/lib/chrony

# Erro máximo tolerado em ppm em relação aos servidores
maxupdateskew 100.0

# Habilita a sincronização via kernel do real-time clock a cada 11 minutos
rtcsync

# Ajusta a hora do sistema com um "salto", de uma só vez, ao invés de
# ajustá-la aos poucos corrigindo a frequência, mas isso apenas se o erro
# for maior do que 1 segundo e somente para os 3 primeiros ajustes
makestep 1 3

# Diretiva que indica que o offset UTC e leapseconds devem ser lidos
# da base tz (de time zone) do sistema
leapsectz right/UTC
EOF

# 5. Reinicia o serviço Chrony para aplicar as novas configurações
echo "Reiniciando o serviço Chrony..."
systemctl restart chrony

# 6. Verifica o status do serviço Chrony
echo "Verificando o status do Chrony..."
systemctl status chrony --no-pager

# 7. Exibe informações de sincronização
echo "Verificando a sincronização do tempo (pode levar alguns segundos para sincronizar)..."
chronyc tracking > /tmp/sincronizar.log
chronyc sources >> /tmp/sincronizar.log
chronyc -N authdata >> /tmp/sincronizar.log

echo "Instalação e configuração do Chrony concluídas."
echo "Verifique os resultados dos comandos 'chronyc tracking', 'chronyc sources' e 'chronyc -N authdata' para confirmar o funcionamento. Estão em /tmp/sincronizar.log"