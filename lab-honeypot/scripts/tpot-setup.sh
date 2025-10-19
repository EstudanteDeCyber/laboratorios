#!/usr/bin/env bash
# scripts/tpot-setup.sh
# Prepara o host (Ubuntu 22.04) e instala o T-Pot automaticamente como usuário 'vagrant'.
# Executar como root (Vagrant provisioner com privileged: true)
set -euo pipefail

# Configuráveis via environment (defina no Vagrantfile ou export antes)
TPOT_USER="${TPOT_USER:-vagrant}"
TPOT_TYPE="${TPOT_TYPE:-h}"                # h=Hive, s=Sensor, etc.
TPOT_WEBUSER="${TPOT_WEBUSER:-admin}"
TPOT_WEBPW="${TPOT_WEBPW:-ChangeMe123!}"   # evite hardcode em repositórios públicos

# Requisitos mínimos (checagem simples)
MIN_MEM_GB=8
MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_GB=$(( MEM_KB / 1024 / 1024 ))
if [ "${MEM_GB}" -lt "${MIN_MEM_GB}" ]; then
  echo "WARNING: Máquina tem ${MEM_GB}GB RAM. Recomendado >= ${MIN_MEM_GB}GB para T-Pot."
fi

echo "==> Instalando dependências básicas..."
sudo apt-get install -y curl sudo gnupg2 ca-certificates lsb-release apache2-utils

# Instalar Docker (recomendo usar o método do upstream)
echo "==> Instalando Docker..."
# remover velhos pacotes, se houver
apt-get remove -y docker docker-engine docker.io containerd runc podman-docker || true
apt-get autoremove -y || true

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

ARCH=$(dpkg --print-architecture)
. /etc/os-release
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Ajustes recomendados para containers / ES
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "storage-driver": "overlay2"
}
EOF

systemctl enable --now containerd docker
sleep 2
systemctl daemon-reload
systemctl restart docker || true

# sysctl tuning (vm.max_map_count required by Elasticsearch)
cat > /etc/sysctl.d/99-tpot.conf <<'EOF'
fs.inotify.max_user_watches=524288
vm.max_map_count=262144
EOF
sysctl --system || true

# Adiciona usuário ao grupo docker
usermod -aG docker "${TPOT_USER}" || true
echo "==> Usuário ${TPOT_USER} adicionado ao grupo docker (re-login necessário para efeito em sessão existente)."

# Baixa o instalador do T-Pot para a home do usuário (garantir permissão)
INSTALL_SH="/home/${TPOT_USER}/install.sh"
echo "==> Baixando install.sh para ${INSTALL_SH}..."
curl -sL https://github.com/telekom-security/tpotce/raw/master/install.sh -o "${INSTALL_SH}"
chmod +x "${INSTALL_SH}"
chown "${TPOT_USER}:${TPOT_USER}" "${INSTALL_SH}"

# Executa o instalador como usuário não-root (vagrant) em modo não interativo
echo "==> Executando install.sh do T-Pot como ${TPOT_USER} (modo automático)..."
# montar o comando com segurança — não expor senha em logs se possível
# Passamos flags: -s (suppress prompts) -t (type) -u (web user) -p (web pw)
# ajusta conforme necessidade; use variáveis de ambiente para segredos
sudo -u "${TPOT_USER}" env bash "${INSTALL_SH}" -s -t "${TPOT_TYPE}" -u "${TPOT_WEBUSER}" -p "${TPOT_WEBPW}" 2>&1 | tee /home/${TPOT_USER}/tpot-install-output.log

# Corrigir propriedade de artefatos gerados
chown -R "${TPOT_USER}:${TPOT_USER}" /home/${TPOT_USER}/tpot*
chown "${TPOT_USER}:${TPOT_USER}" /home/${TPOT_USER}/tpot-install-output.log

# ===============================================================
# SSH Config
# ===============================================================
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^PubkeyAuthentication yes/#PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
echo "vagrant:vagrant" | chpasswd

# ===============================================================
# Ajustar Placa de REDE para o IP específico
# ===============================================================
cp /etc/network/interfaces /etc/network/interfaces.bak || true
cat << 'EONET' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
address 192.168.50.50
netmask 255.255.255.0
gateway 192.168.50.1
EONET

echo "==> Instalação T-Pot finalizada. Verifique /home/${TPOT_USER}/tpot-install-output.log e /home/${TPOT_USER}/install_tpot.log (Ansible log)."
echo "==> Recomenda-se reboot da VM. Se quiser automatizar, descomente o reboot abaixo."
# reboot now (opcional)
reboot