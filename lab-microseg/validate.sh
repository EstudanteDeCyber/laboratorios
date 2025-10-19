#!/usr/bin/env bash
# validate.sh - Smoke test do laboratório de microsegmentação
set -euo pipefail

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
fail()  { echo -e "${RED}[FAIL]${RESET} $*"; exit 1; }

echo "=== Validação do Lab ==="

# 1. Checar status das VMs
echo "[1] Verificando Vagrant..."
if vagrant status | grep -q "running (virtualbox)"; then
  ok "Todas as VMs estão rodando."
else
  fail "Algumas VMs não estão rodando."
fi

# 2. Conectar no master
MASTER="lab-master"
echo "[2] Verificando conexão SSH com $MASTER..."
if vagrant ssh "$MASTER" -c "echo hello" | grep -q hello; then
  ok "Conexão SSH com $MASTER funcionando."
else
  fail "Falha ao conectar no $MASTER."
fi

# 3. Kubernetes nodes
echo "[3] Verificando Kubernetes..."
if vagrant ssh "$MASTER" -c "kubectl get nodes --no-headers" | grep -q "Ready"; then
  ok "Cluster Kubernetes ativo e nodes em Ready."
else
  fail "Cluster Kubernetes não está pronto."
fi

# 4. CNI pods
echo "[4] Checando pods de rede (Calico/Cilium)..."
if vagrant ssh "$MASTER" -c "kubectl get pods -A --no-headers" | grep -E "calico|cilium" >/dev/null; then
  ok "Pods de rede detectados (Calico ou Cilium)."
else
  warn "Nenhum pod de rede detectado — verifique se aplicou o CNI."
fi

# 5. NetworkPolicy quick test
echo "[5] Testando NetworkPolicy básica..."
vagrant ssh "$MASTER" -c "
kubectl delete ns app --ignore-not-found
kubectl create ns app
kubectl run backend --image=hashicorp/http-echo --namespace=app --port=8080 -- -text=backend-ok
kubectl run frontend --image=nginx --namespace=app --port=80
kubectl wait --for=condition=Ready pod -n app -l app=backend --timeout=60s
kubectl wait --for=condition=Ready pod -n app -l run=frontend --timeout=60s
" >/dev/null 2>&1 || fail "Falha ao criar pods de teste."

sleep 5
if vagrant ssh "$MASTER" -c "kubectl exec -n app frontend -- curl -s backend:8080" | grep -q backend-ok; then
  ok "Conectividade inicial frontend→backend OK."
else
  fail "Conectividade inicial falhou."
fi

vagrant ssh "$MASTER" -c "kubectl apply -f /vagrant/manifests/deny-all.yaml" >/dev/null
sleep 3
if vagrant ssh "$MASTER" -c "kubectl exec -n app frontend -- curl -s --max-time 5 backend:8080" >/dev/null 2>&1; then
  fail "deny-all não bloqueou comunicação."
else
  ok "deny-all bloqueou comunicação como esperado."
fi

vagrant ssh "$MASTER" -c "kubectl apply -f /vagrant/manifests/allow-frontend-to-backend.yaml" >/dev/null
sleep 5
if vagrant ssh "$MASTER" -c "kubectl exec -n app frontend -- curl -s backend:8080" | grep -q backend-ok; then
  ok "allow-frontend-to-backend reestabeleceu comunicação."
else
  fail "allow-frontend-to-backend não funcionou."
fi

# 6. nftables
echo "[6] Verificando nftables..."
if vagrant ssh "$MASTER" -c "sudo nft list ruleset" | grep -q "chain input"; then
  ok "Regras nftables presentes."
else
  warn "Nenhuma regra nftables encontrada."
fi

# 7. OVS
echo "[7] Verificando Open vSwitch..."
if vagrant ssh "$MASTER" -c "sudo ovs-vsctl show" | grep -q "Bridge"; then
  ok "Bridge(s) OVS detectada(s)."
else
  warn "Nenhuma bridge OVS detectada."
fi

echo -e "${GREEN}=== Validação concluída com sucesso! ===${RESET}"