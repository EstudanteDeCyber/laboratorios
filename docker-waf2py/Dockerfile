# Base image
FROM debian:bullseye-slim

# Evitar prompts interativos durante a instalação
ENV DEBIAN_FRONTEND=noninteractive

# Atualizar e instalar pacotes básicos
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y \
    wget \
    git \
    vim \
    libmodsecurity-dev \
    python3-pip \
    cron \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Instalar pacotes Python necessários
RUN pip3 install netifaces psutil

# Clonar os repositórios necessários
RUN git clone https://github.com/SpiderLabs/owasp-modsecurity-crs.git /opt/owasp-modsecurity-crs \
    && git clone https://github.com/ITSec-Chile/Waf2Py.git /opt/Waf2Py

RUN rm -rf /opt/owasp-modsecurity-crs/.git /opt/Waf2Py/.git

# Definir o diretório de trabalho
WORKDIR /opt/Waf2Py/installer

# Corrigir linha interativa no script do instalador
RUN sed -i 's|openssl req -new -x509.*key .*self_signed.key|openssl req -new -x509 -nodes -sha1 -days 365 -subj "/C=BR/ST=SP/L=SaoPaulo/O=Waf2Py/CN=waf2py.local" -key /etc/apache2/ssl/self_signed.key -out /etc/apache2/ssl/self_signed.cert|' /opt/Waf2Py/installer/waf2py_installer.sh

# Comentar o reboot no script e executá-lo
RUN sed -i 's|/sbin/reboot|# /sbin/reboot|' waf2py_installer.sh && \
    chmod +x waf2py_installer.sh && \
    ./waf2py_installer.sh && \
    crontab -l 2>/dev/null | cat | crontab -

# Configurar o ServerName do Apache
RUN echo "ServerName waf2py.local" >> /etc/apache2/conf-available/servername.conf && \
    a2enconf servername

# Ajustar permissões do diretório da aplicação
RUN chown -R www-data:www-data /home/www-data \
    && chmod -R u+w /home/www-data
	
# Garantir permissões finais para o banco
RUN chown -R www-data:www-data /home/www-data/waf2py_community/applications/Waf2Py/databases
	
# Expor a porta usada pela aplicação
EXPOSE 62443

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
CMD ["/usr/local/bin/entrypoint.sh"]
