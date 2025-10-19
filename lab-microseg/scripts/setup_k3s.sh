#!/usr/bin/env bash
set -euo pipefail
# Instala k3s (executar como root)
curl -sfL https://get.k3s.io | sh -
echo "k3s instalado"