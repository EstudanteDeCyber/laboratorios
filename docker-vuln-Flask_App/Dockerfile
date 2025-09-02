FROM debian:bullseye-slim

RUN apt-get clean \
    && apt-get -y update

RUN apt-get -y install nginx \
    && apt-get -y install python3-dev \
    && apt-get -y install build-essential \
    && apt-get -y install uwsgi \
    && apt-get -y install uwsgi-plugin-python3 \
    && apt-get -y install python3-pip

COPY conf/nginx.conf /etc/nginx
COPY --chown=www-data:www-data . /srv/flask_app

WORKDIR /srv/flask_app
RUN pip3 install -r requirements.txt --src /usr/local/src

CMD ["sh", "-c", "service nginx start && uwsgi --ini uwsgi.ini"]
