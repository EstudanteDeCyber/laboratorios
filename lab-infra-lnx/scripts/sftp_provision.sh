#!/bin/bash

# Atualiza os pacotes
export DEBIAN_FRONTEND=noninteractive
apt update -y && apt install -y openssh-server

# Cria o grupo para os usuários SFTP
groupadd sftpusers

# Cria o usuário SFTP e o adiciona ao grupo sftpusers, com shell nologin
useradd -m -g sftpusers -s /usr/sbin/nologin sftpuser1
echo "sftpuser1:change-me" | chpasswd

# Cria o diretório raiz para o chroot do sftpuser1
# Este diretório E TODOS OS SEUS PAIS devem ser de propriedade do root e NÃO graváveis por grupo/outros.
# Isso é uma exigência de segurança do OpenSSH para o chroot.
sudo mkdir -p /var/sftp/sftpuser1/
sudo chown root:root /var/sftp/sftpuser1
sudo chmod 755 /var/sftp/sftpuser1

# Cria um subdiretório dentro do chroot onde o sftpuser1 REALMENTE terá permissão para gravar.
# Este diretório deve ser de propriedade do sftpuser1.
sudo mkdir /var/sftp/sftpuser1/uploads
sudo chown sftpuser1:sftpusers /var/sftp/sftpuser1/uploads
# Permissão 755 permite ao dono (sftpuser1) ler/gravar/executar, e grupo/outros apenas ler/executar.
# Se o sftpuser1 precisa GRAVAR arquivos (fazer upload), esta permissão é adequada.
# Se quiser que outros no grupo sftpusers também possam gravar, use 775.
sudo chmod 755 /var/sftp/sftpuser1/uploads

# Configura o arquivo de configuração do SSH para usar SFTP interno e chroot

sed -i '115s/^/# /' /etc/ssh/sshd_config

echo "
# Configuração de SFTP com Chroot
Subsystem sftp internal-sftp

# Restrição de acesso por grupo SFTP
Match Group sftpusers
    ChrootDirectory /sftp/%u
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
	PasswordAuthentication yes
" >> /etc/ssh/sshd_config

# Reinicia o serviço SSH para aplicar as configurações
systemctl restart sshd

# Teste a instalação (opcional)
# sftp sftpuser1@localhost

echo "Configuração do SFTP com Chroot concluída!"
