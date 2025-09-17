
# activate_vulnerabilities.ps1
# Script para ativar vulnerabilidades no laboratório de Active Directory e LDAP
# Este script deve ser executado no DC01

Import-Module ActiveDirectory

# 1. Credenciais Fracas ou Padrão
# Cria um usuário com senha fraca
Write-Host "Ativando vulnerabilidade: Credenciais Fracas ou Padrão..."
New-ADUser -Name "usuario.fraco" -GivenName "Usuario" -Surname "Fraco" -SamAccountName "ufraco" -Path "OU=Usuarios,DC=lab,DC=local" -AccountPassword (ConvertTo-SecureString "senha123" -AsPlainText -Force) -Enabled $true
Write-Host "Usuário 'ufraco' criado com senha 'senha123'."

# 2. Ataques de Força Bruta e Pulverização de Senhas
# Relaxa as políticas de bloqueio de conta na GPO padrão do domínio
Write-Host "Ativando vulnerabilidade: Força Bruta e Pulverização de Senhas (relaxando políticas de bloqueio)..."
$gpo = Get-GPO -Name "Default Domain Policy"
Set-GPO -Guid $gpo.Id -Policy `
    @{`
        "AccountLockoutThreshold"="0"; `
        "LockoutDuration"="0"; `
        "ResetLockoutCountAfter"="0"`
    }
# Forçar atualização da GPO
Invoke-GPUpdate -Force -Target "Computer"
Write-Host "Políticas de bloqueio de conta relaxadas na 'Default Domain Policy'."

# 3. Kerberoasting
# Cria uma conta de serviço com SPN e senha fraca
Write-Host "Ativando vulnerabilidade: Kerberoasting..."
$ServiceAccountPassword = ConvertTo-SecureString "Servico123!" -AsPlainText -Force
New-ADUser -Name "ServicoWeb" -SamAccountName "svcweb" -Path "OU=Servidores,DC=lab,DC=local" -AccountPassword $ServiceAccountPassword -Enabled $true
Set-ADUser -Identity svcweb -ServicePrincipalNames @("HTTP/webserver.lab.local")
Write-Host "Conta de serviço 'svcweb' criada com SPN 'HTTP/webserver.lab.local' e senha fraca."

# 4. AS-REP Roasting
# Cria um usuário que não exige pré-autenticação Kerberos
Write-Host "Ativando vulnerabilidade: AS-REP Roasting..."
$ASREPUserPassword = ConvertTo-SecureString "ASREPUser123!" -AsPlainText -Force
New-ADUser -Name "ASREPUser" -SamAccountName "asrepuser" -Path "OU=Usuarios,DC=lab,DC=local" -AccountPassword $ASREPUserPassword -Enabled $true
Set-ADUser -Identity asrepuser -DontRequirePreauth $true
Write-Host "Usuário 'asrepuser' criado e configurado para não exigir pré-autenticação Kerberos."

# 5. Enumeração de Nomes de Usuário e Grupos
# Esta vulnerabilidade é mais sobre a observação do atacante.
# O AD por padrão permite a enumeração de usuários autenticados.
Write-Host "Vulnerabilidade: Enumeração de Nomes de Usuário e Grupos. O Active Directory permite a enumeração por padrão."

Write-Host "Ativação de vulnerabilidades concluída. Lembre-se de que algumas alterações de GPO podem levar tempo para se propagar."


