#!/bin/bash
docker compose -f ../docker-waf2py/docker-compose.yml \
               -f ../docker-hashicorp_vault/docker-compose.yml \
               -f ../docker-nessus-essentials/docker-compose.yml \
               -f ../docker-gophish/docker-compose.yml \
               -f ../docker-inbucket/docker-compose.yml \
               -f ../docker-openvas/docker-compose.yml \
               -f ../docker-splunk/docker-compose.yml \
               down
