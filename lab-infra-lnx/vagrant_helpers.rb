# Diretórios padrão para scripts e chaves sincronizados com as VMs
SCRIPT_DIR = "scripts"
KEY_DIR = "keys"

# Nome da rede interna usada por todas as VMs
NETWORK_NAME = "infraopen_network"

# Caminho da chave pública do host Windows (ajustar conforme necessário)
HOST_SSH_PUB_PATH = "C:/Users/Hugo/.ssh/id_rsa.pub"

# ---
# Configuração comum para uma VM (exceto firewall), incluindo rede, recursos e scripts básicos.
def common_vm_config(node, opts = {})
  node.vm.box = opts.fetch(:box, "debian/bookworm64")
  node.vm.hostname = opts[:hostname]

  if opts[:ip]
    node.vm.network "private_network", ip: opts[:ip], virtualbox__intnet: NETWORK_NAME, mac: opts[:mac]
  else
    node.vm.network "private_network", type: "dhcp", virtualbox__intnet: NETWORK_NAME, mac: opts[:mac]
  end

  setup_virtualbox_provider(node, memory: opts[:memory] || 1024, cpus: opts[:cpus] || 1, name: opts[:hostname])
  setup_common(node)

  # Aceita a chave pública da firewall (pré-sincronizada)
  authorize_firewall_key(node, "vagrant")

  provision_scripts(node, opts[:scripts]) if opts[:scripts]
end

# ---
# Configurações específicas da VM firewall
def configure_firewall(node)
  setup_virtualbox_provider(node, memory: 2048, cpus: 2, name: "firewall")
  setup_common(node)

  # 1. Copia a chave pública do host para a pasta /home/vagrant na VM
  node.vm.provision "file", source: HOST_SSH_PUB_PATH, destination: "/home/vagrant/id_rsa.pub"

  # Ajuste senha root e configuração da chave pública no usuário vagrant
  node.vm.provision "shell", inline: <<-SHELL
    # Senha do root
    echo "root:p@ssw0rd" | chpasswd

    # 2. Usa a chave a partir de /home/vagrant e depois a apaga
    mkdir -p /home/vagrant/.ssh
    cat /home/vagrant/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
    rm /home/vagrant/id_rsa.pub # Boa prática: remove o arquivo temporário

    chown -R vagrant:vagrant /home/vagrant/.ssh
    chmod 700 /home/vagrant/.ssh
    chmod 600 /home/vagrant/.ssh/authorized_keys
  SHELL

  # Gera nova chave para vagrant e exporta a pública
  node.vm.provision "shell", inline: <<-SHELL
    USER_HOME=/home/vagrant
    rm -f "$USER_HOME/.ssh/id_rsa" "$USER_HOME/.ssh/id_rsa.pub"
    sudo -u vagrant ssh-keygen -t rsa -b 4096 -f "$USER_HOME/.ssh/id_rsa" -N "" -q

    mkdir -p /tmp/tmp_key
    cp "$USER_HOME/.ssh/id_rsa.pub" /tmp/tmp_key/firewall_vagrant.pub
    chmod 644 /tmp/tmp_key/firewall_vagrant.pub
  SHELL
end

# Nas outras VMs, aceita a chave gerada pela firewall
def authorize_firewall_key(node, username)
  node.vm.provision "shell", inline: <<-SHELL
    USERNAME=#{username}
    USER_HOME=$(eval echo "~$USERNAME")

    mkdir -p "$USER_HOME/.ssh"
    chown $USERNAME:$USERNAME "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"

    if [ -f /tmp/tmp_key/firewall_vagrant.pub ]; then
      cat /tmp/tmp_key/firewall_vagrant.pub >> "$USER_HOME/.ssh/authorized_keys"
      chown $USERNAME:$USERNAME "$USER_HOME/.ssh/authorized_keys"
      chmod 600 "$USER_HOME/.ssh/authorized_keys"
    else
      echo "Chave pública da firewall não encontrada"
      exit 1
    fi
  SHELL
end

# Envia scripts e chaves para a VM e executa os scripts
def provision_scripts(node, scripts)
  node.vm.provision "file", source: "./#{SCRIPT_DIR}", destination: "/tmp/scripts"
  node.vm.provision "file", source: "./#{KEY_DIR}", destination: "/tmp/tmp_key"

  scripts.compact.each do |script|
    node.vm.provision "shell", inline: <<-SHELL
      chmod +x /tmp/scripts/#{script}
      /tmp/scripts/#{script}
    SHELL
  end
end

# Scripts comuns: atualização e teclado
def setup_common(node)
  common_scripts = ["atualizacao.sh", "keyboard.sh", "configurar-syslog-chrony.sh"]
  provision_scripts(node, common_scripts)
end

# ---
# Configura recursos do VirtualBox
def setup_virtualbox_provider(node, opts = {})
  node.vm.provider "virtualbox" do |vb|
    vb.memory = opts.fetch(:memory, 1024)
    vb.cpus = opts.fetch(:cpus, 1)
    vb.name = opts[:name] if opts[:name]
    vb.customize ["modifyvm", :id, "--usb", "off"]
    vb.customize ["modifyvm", :id, "--audio-enabled", "off"]
  end
end