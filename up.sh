#!/bin/bash
docker compose -f waf2py/docker-compose.yml \
               -f hashicorp_vault/docker-compose.yml \
               -f nessus-essentials/docker-compose.yml \
               -f gophish/docker-compose.yml \
               -f inbucket/docker-compose.yml \
               up -d
