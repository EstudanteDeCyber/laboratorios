# ===============================
# CLI01_PROVISION.PS1 - CONFIGURACAO DE REDE E JOIN AO DOMINIO
# ===============================

Write-Host "=== AJUSTANDO REDE NO CLI01 ===" -ForegroundColor Cyan

# Solicita usuario e senha do dominio
$domainUser     = Read-Host "DIGITE O USUARIO DO DOMINIO (EX: LAB\ADMINISTRATOR)"
$domainPassword = Read-Host "DIGITE A SENHA DO USUARIO" -AsSecureString
$credential     = New-Object System.Management.Automation.PSCredential($domainUser, $domainPassword)

# Variaveis de rede (sem gateway e DNS)
$ipAddress     = "10.10.10.32"
$prefixLength  = 24

# Detecta interface ativa principal
$nic = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1

if (-not $nic) {
    Write-Host "NENHUMA INTERFACE DE REDE ATIVA ENCONTRADA." -ForegroundColor Red
    exit
}

$nicName = $nic.Name
Write-Host ("INTERFACE DETECTADA: {0}" -f $nicName) -ForegroundColor Yellow

# ===============================
# LIMPEZA DE ENDEREÇOS IP EXISTENTES
# ===============================
Write-Host "=== LIMPEZA DE ENDEREÇOS IP EXISTENTES ===" -ForegroundColor Cyan

# Remove IPs existentes
Get-NetIPAddress -InterfaceAlias $nicName -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "LIMPEZA DE IPs CONCLUIDA" -ForegroundColor Green

# ===============================
# CONFIGURACAO DE IP ESTATICO
# ===============================
Write-Host "=== CONFIGURANDO IP ESTATICO ===" -ForegroundColor Cyan

# Define apenas o IP, sem gateway
New-NetIPAddress -InterfaceAlias $nicName -IPAddress $ipAddress -PrefixLength $prefixLength -ErrorAction Stop

Write-Host ("NIC '{0}' CONFIGURADA COM IP {1}" -f $nicName, $ipAddress) -ForegroundColor Green

# ===============================
# ATUALIZANDO ARQUIVO HOSTS
# ===============================
Write-Host "=== ADICIONANDO ENTRADAS NO ARQUIVO HOSTS ===" -ForegroundColor Cyan

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"

$entries = @(
    "10.10.10.30 idp01.local"
    "10.10.10.31 app01.local"
)

foreach ($entry in $entries) {
    if (-not (Select-String -Path $hostsPath -Pattern [regex]::Escape($entry) -Quiet)) {
        Add-Content -Path $hostsPath -Value $entry
        Write-Host "ADICIONADO: $entry" -ForegroundColor Green
    } else {
        Write-Host "JA EXISTE: $entry" -ForegroundColor Yellow
    }
}

Write-Host "=== SCRIPT CONCLUIDO ===" -ForegroundColor Cyan