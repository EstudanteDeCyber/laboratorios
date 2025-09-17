1 - provisionar + updates
.\vagrant-up.ps1 (rebootar a Win11 durante o provisionamento, caso nao inicie/trave)

2 - Ajustar placa externa
.\post_deploy_script.ps1

3 - dc01 logar e rodar:
cmd
c:\tmp\
.\dc01_provision_1.ps1

3.1 - dc01 logar e rodar:
cmd
c:\tmp\
.\dc01_provision_2.ps1

3.2 - dc1 criar user domain admin
.\cria_user_ad.ps1

4- srv01 logar e rodar:
cmd
c:\tmp\
.\srv01_provision.ps1

4 - cli01 logar e rodar:
cmd
cd c:\tmp\
.\cli01_provision.ps1