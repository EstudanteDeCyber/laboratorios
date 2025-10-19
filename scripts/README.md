Como o vagrant-up.ps1 funciona:

1 - Define qual Vagrantfile usar, buscando um arquivo que comece com Vagrantfile_ no diretório atual.
2 - Seta variável de ambiente VAGRANT_VAGRANTFILE para esse arquivo.
3 - Define o diretório dos scripts (baseado na pasta pai do projeto atual + scripts).
4 - Muda o diretório de trabalho para o projeto, garantindo que o vagrant up rode ali.
5 - Executa o comando vagrant up (ou outro passado via argumento).
6 - Se o comando for up ou vazio, roda um script pos_install_*.ps1 que depende do sufixo do Vagrantfile.
7 - Restaura a configuração original do VirtualBox.