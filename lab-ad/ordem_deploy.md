
# 1 - Vagrant up provisão + updates (rebootar a Win11 durante o provisionamento, caso nao inicie/trave)
- copiar o script de scrtips/vagrant-up.ps1 para a pasta lab-ad [ou add no path do SO]
.\vagrant-up.ps1 ou 'vagrant up' caso nao use o script;

# Ajustes de placas de redes para isolar lan após depoy
- copiar o script de scrtips/post_deploy_script.ps1 para a pasta lab-ad [ou add no path do SO]
.\post_deploy_script.ps1

# 3.1 - Provisionamento do DC01, logar e rodar:
cmd
c:\tmp\
.\dc01_provision_1.ps1

# 3.2 - Provisionamento do DC01, logar e rodar:
cmd
c:\tmp\
.\dc01_provision_2.ps1

# 3.3 - Provisionamento do DC01, logar e rodar:
cmd
c:\tmp\
.\cria_user_ad.ps1

# 4 - Provisionamento do srv01,  logar e rodar:
cmd
c:\tmp\
.\srv01_provision.ps1

# 5 - Provisionamento do cli01, logar e rodar:
cmd
cd c:\tmp\
.\cli01_provision.ps1
