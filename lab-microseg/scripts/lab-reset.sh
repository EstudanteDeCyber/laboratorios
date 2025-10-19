#!/bin/bash
set -euo pipefail

echo "==> Removendo manifests do lab (ignorar erros)..."
kubectl delete -f /vagrant/manifests/attacker-vulnerable.yaml --ignore-not-found || true
kubectl delete -f /vagrant/manifests/contain-attacker.yaml --ignore-not-found || true
kubectl delete -f /vagrant/manifests/pci_policies.yaml --ignore-not-found || true
kubectl delete -f /vagrant/manifests/pci_style_deploys.yaml --ignore-not-found || true
kubectl delete -f /vagrant/manifests/backend-egress-dns-only.yaml --ignore-not-found || true

echo "==> Aguardando pods serem removidos..."
kubectl wait --for=delete pod -n app --all --timeout=60s || true
kubectl wait --for=delete pod -n red --all --timeout=60s || true

echo "==> Limpando nftables..."
if command -v nft >/dev/null 2>&1; then
  sudo nft flush ruleset || true
fi

echo "==> Removendo bridge OVS (se existir)..."
if command -v ovs-vsctl >/dev/null 2>&1; then
  sudo ovs-vsctl --if-exists del-br br0 || true
fi

echo "==> Operação de reset concluída."