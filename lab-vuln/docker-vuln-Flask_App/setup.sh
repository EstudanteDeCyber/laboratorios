#!/bin/bash

# Define variáveis de diretório
BASE_DIR="/home/vagrant/laboratorio/lab-vuln/docker-vuln-Flask_App"
REPO_DIR="$BASE_DIR/extremely-vulnerable-flask-app"

# Garante que o diretório base existe
cd "$BASE_DIR"

# Clona o repositório se ainda não existir
if [ ! -d "$REPO_DIR" ]; then
  git clone https://github.com/manuelz120/extremely-vulnerable-flask-app
fi

# Entra no diretório do projeto
cd "$REPO_DIR"

# Recriar o Dockerfile
cat <<EOF > Dockerfile
FROM debian:bullseye-slim

RUN apt-get clean \\
    && apt-get -y update

RUN apt-get -y install nginx \\
    && apt-get -y install python3-dev \\
    && apt-get -y install build-essential \\
    && apt-get -y install uwsgi \\
    && apt-get -y install uwsgi-plugin-python3 \\
    && apt-get -y install python3-pip

COPY conf/nginx.conf /etc/nginx
COPY --chown=www-data:www-data . /srv/flask_app

WORKDIR /srv/flask_app
RUN pip3 install -r requirements.txt --src /usr/local/src

CMD ["sh", "-c", "service nginx start && uwsgi --ini uwsgi.ini"]
EOF

# Builda a imagem Docker
docker build . -t extremely_vulnerable_flask_app

# Remove o container existente, se já estiver rodando
if docker ps -a --format '{{.Names}}' | grep -Eq "^extremely_vulnerable_flask_app\$"; then
  docker rm -f extremely_vulnerable_flask_app
fi

# Roda o container
docker run -d --restart unless-stopped -p 5000:80 --name extremely_vulnerable_flask_app extremely_vulnerable_flask_app
