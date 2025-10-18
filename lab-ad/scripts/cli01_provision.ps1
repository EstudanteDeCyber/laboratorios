# ===============================
# CLI01_PROVISION.PS1 - CONFIGURACAO DE REDE E JOIN AO DOMINIO
# ===============================

Write-Host "=== AJUSTANDO REDE NO CLI01 ===" -ForegroundColor Cyan

# Solicita usuario e senha do dominio
$domainUser     = Read-Host "DIGITE O USUARIO DO DOMINIO (EX: LAB\ADMINISTRATOR)"
$domainPassword = Read-Host "DIGITE A SENHA DO USUARIO" -AsSecureString
$credential     = New-Object System.Management.Automation.PSCredential($domainUser, $domainPassword)

# Variaveis de rede
$ipAddress     = "10.10.10.22"
$prefixLength  = 24
$gateway       = "10.10.10.254"
$dnsServer     = "10.10.10.20"

# Detecta interface ativa principal
$nic = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1

if (-not $nic) {
    Write-Host "NENHUMA INTERFACE DE REDE ATIVA ENCONTRADA." -ForegroundColor Red
    exit
}

$nicName = $nic.Name
Write-Host ("INTERFACE DETECTADA: {0}" -f $nicName) -ForegroundColor Yellow

# ===============================
# LIMPEZA COMPLETA DE IP, GATEWAY E DNS EXISTENTES
# ===============================
Write-Host "=== LIMPEZA COMPLETA DE IP, GATEWAY E DNS EXISTENTES ===" -ForegroundColor Cyan

# Remove IPs existentes
Get-NetIPAddress -InterfaceAlias $nicName -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

# Remove gateways existentes
Get-NetRoute -InterfaceAlias $nicName -ErrorAction SilentlyContinue |
    Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } |
    Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

# Reseta DNS
Set-DnsClientServerAddress -InterfaceAlias $nicName -ResetServerAddresses -ErrorAction SilentlyContinue

Write-Host "LIMPEZA CONCLUIDA" -ForegroundColor Green

# ===============================
# CONFIGURACAO DE IP ESTATICO, GATEWAY E DNS
# ===============================
Write-Host "=== CONFIGURANDO IP ESTATICO, GATEWAY E DNS ===" -ForegroundColor Cyan

# Define IP e Gateway
New-NetIPAddress -InterfaceAlias $nicName -IPAddress $ipAddress -PrefixLength $prefixLength -DefaultGateway $gateway -ErrorAction Stop

# Define DNS
Set-DnsClientServerAddress -InterfaceAlias $nicName -ServerAddresses $dnsServer -ErrorAction Stop

Write-Host ("NIC '{0}' CONFIGURADA COM IP {1}, GATEWAY {2} E DNS {3}" -f $nicName, $ipAddress, $gateway, $dnsServer) -ForegroundColor Green

# ===============================
# VERIFICACAO DE DISPONIBILIDADE DO DC
# ===============================
Write-Host ("=== AGUARDANDO DISPONIBILIDADE DO DC ({0}) ===" -f $dnsServer) -ForegroundColor Cyan

do {
    Start-Sleep -Seconds 5
    $ping = Test-Connection -ComputerName $dnsServer -Count 1 -Quiet
} while (-not $ping)

Write-Host "DC DISPONIVEL. PROSSEGUINDO COM JOIN AO DOMINIO..." -ForegroundColor Green

# ===============================
# JOIN AO DOMINIO
# ===============================
$domainName = "lab.local"
try {
    Add-Computer -DomainName $domainName -Credential $credential -Restart -Force
    Write-Host ("CLI01 FOI ADICIONADO AO DOMINIO {0} E SERA REINICIADO" -f $domainName) -ForegroundColor Green
} catch {
    Write-Host ("ERRO AO ADICIONAR CLI01 AO DOMINIO: {0}" -f $_.Exception.Message) -ForegroundColor Red
}
