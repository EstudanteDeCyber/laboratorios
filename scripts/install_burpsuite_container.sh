#!/bin/bash
cd /home/vagrant
git clone https://github.com/hexcowboy/docker-burp-suite-community.git && cd docker-burp-suite-community
sed -i 's|FROM openjdk:11-jre-slim|FROM openjdk:21-jdk-slim-bullseye|' Dockerfile
sed -i 's|ttf-dejavu|ttf-bitstream-vera|' Dockerfile
docker build -t burpsuite .
