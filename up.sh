#!/bin/bash
docker compose -f waf2py/docker-compose.yml \
               -f hashicorp_vault/docker-compose.yml \
               -f nessus-essentials/docker-compose.yml \
               -f gophish/docker-compose.yml \
               -f inbucket/docker-compose.yml \
               -f openvas/docker-compose.yml \
               -f burp-suite/docker-compose.yml \
               -f splunk/docker-compose.yml \
               up -d
