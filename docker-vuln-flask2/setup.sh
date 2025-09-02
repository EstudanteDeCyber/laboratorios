#!/bin/bash

cd /home/vagran/lab-sec/docker-vuln-flask2
git clone https://github.com/Lucas-Vini/vul-flask
cd vul-flask 
sed -i 's/arm/amd/g' compose.yaml
docker-compose up -d
