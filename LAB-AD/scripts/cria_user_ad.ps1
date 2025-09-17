Write-Host "=== INICIANDO CRIACAO DE USUARIO(S) NO AD ==="

# VARIAVEIS DO DOMINIO
$domainDN   = "DC=lab,DC=local"        
$ouName     = "Users"                  
$ouPath     = "OU=$ouName,$domainDN"   

# SOLICITA INFORMACOES
$userInput  = Read-Host "DIGITE O(S) NOME(S) DE USUARIO (SEPARADOS POR VIRGULA)"
$grupo      = Read-Host "DIGITE O GRUPO PARA ADICIONAR OS USUARIOS (EX: Domain Users, Domain Admins)"

# TRANSFORMA ENTRADA EM LISTA (REMOVE ESPACOS EXTRAS)
$userList = $userInput -split "," | ForEach-Object { $_.Trim() }

# IMPORTA MODULO AD
Import-Module ActiveDirectory

# GARAANTE QUE A OU EXISTE
$ouExists = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchBase $domainDN -ErrorAction SilentlyContinue
if ($ouExists) {
    Write-Host "OU '$ouName' JA EXISTE."
} else {
    New-ADOrganizationalUnit -Name $ouName -Path $domainDN
    Write-Host "OU '$ouName' CRIADA EM $domainDN."
}

# FUNCAO PARA GERAR SENHA ALEATORIA
function Gerar-SENHASEGURA($length = 12) {
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()"
    -join ((1..$length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

# LOOP PARA CADA USUARIO
foreach ($username in $userList) {
    if ([string]::IsNullOrWhiteSpace($username)) { continue }

    $displayName = $username
    $randomPassword = Gerar-SENHASEGURA 12
    $securePass = ConvertTo-SecureString $randomPassword -AsPlainText -Force

    # VERIFICA SE USUARIO JA EXISTE
    if (Get-ADUser -Filter { SamAccountName -eq $username } -ErrorAction SilentlyContinue) {
        Write-Host "USUARIO '$username' JA EXISTE NO AD."
    } else {
        try {
            # CRIA USUARIO
            New-ADUser `
                -Name $displayName `
                -SamAccountName $username `
                -UserPrincipalName "$username@lab.local" `
                -Path $ouPath `
                -AccountPassword $securePass `
                -Enabled $true `
                -PasswordNeverExpires $true `
                -ChangePasswordAtLogon $false

            Write-Host "USUARIO '$username' CRIADO COM SUCESSO."

            # ADICIONA AO GRUPO
            Add-ADGroupMember -Identity $grupo -Members $username -ErrorAction Stop
            Write-Host "USUARIO '$username' ADICIONADO AO GRUPO '$grupo'."

            # MOSTRA SENHA
            Write-Host "SENHA GERADA PARA '$username': $randomPassword"
        }
        catch {
            Write-Host "ERRO AO CRIAR USUARIO '$username' OU ADICIONAR AO GRUPO: $($_.Exception.Message.ToUpper())"
        }
    }
}

Write-Host "`nPROCESSO CONCLUIDO."
