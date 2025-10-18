Write-Host "=== POS-REBOOT: CONFIGURANDO REDE E DNS NO DC01 ===" -ForegroundColor Cyan

# Define variaveis de IP e DNS
$ipAddress = "10.10.10.20"
$subnetMask = "255.255.255.0"
$dnsServer = "10.10.10.20"

# ===============================
# CONFIGURACAO DE IP ESTATICO E DNS
# ===============================
$nic = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
$nicName = $nic.Name
Write-Host ("INTERFACE DETECTADA: {0}" -f $nicName) -ForegroundColor Yellow

# Limpa IPs e gateways existentes
Get-NetIPAddress -InterfaceAlias $nicName -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
Get-NetRoute -InterfaceAlias $nicName -ErrorAction SilentlyContinue |
    Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } |
    Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

# Define IP e gateway
New-NetIPAddress -InterfaceAlias $nicName -IPAddress $ipAddress -PrefixLength 24 -DefaultGateway $dnsServer
Set-DnsClientServerAddress -InterfaceAlias $nicName -ServerAddresses $dnsServer

Write-Host ("✅ NIC '{0}' CONFIGURADA COM IP {1}, GATEWAY {2} E DNS {3}" -f $nicName, $ipAddress, $dnsServer, $dnsServer) -ForegroundColor Green

# ===============================
# CRIACAO DE ZONAS DNS
# ===============================
# Zona direta
$zoneName = "lab.local"
if (-not (Get-DnsServerZone -ComputerName localhost | Where-Object {$_.ZoneName -eq $zoneName})) {
    Add-DnsServerPrimaryZone -Name $zoneName -ReplicationScope "Domain" -DynamicUpdate "NonsecureAndSecure" | Out-Null
    Write-Host ("✅ ZONA DNS '{0}' CRIADA" -f $zoneName) -ForegroundColor Green
} else {
    Write-Host ("ZONA DNS '{0}' JA EXISTE" -f $zoneName) -ForegroundColor Yellow
}

# Zona reversa
$reverseZoneName = "10.10.10.in-addr.arpa"
if (-not (Get-DnsServerZone -ComputerName localhost | Where-Object {$_.ZoneName -eq $reverseZoneName})) {
    Add-DnsServerPrimaryZone -NetworkID "10.10.10.0/24" -ReplicationScope "Domain" -DynamicUpdate "NonsecureAndSecure" | Out-Null
    Write-Host ("✅ ZONA DNS REVERSA '{0}' CRIADA" -f $reverseZoneName) -ForegroundColor Green
} else {
    Write-Host ("ZONA DNS REVERSA '{0}' JA EXISTE" -f $reverseZoneName) -ForegroundColor Yellow
}

# ===============================
# RESET DA SENHA DO ADMINISTRATOR DO DOMINIO
# ===============================
Write-Host "=== RESETANDO SENHA DO ADMINISTRATOR DO DOMINIO ===" -ForegroundColor Cyan
Set-ADAccountPassword -Identity "Administrator" -Reset -NewPassword (ConvertTo-SecureString "P@ssw0rd0123!" -AsPlainText -Force)
Write-Host "✅ SENHA DO ADMINISTRATOR DO DOMINIO DEFINIDA PARA 'P@ssw0rd0123!'" -ForegroundColor Green

Write-Host "=== CONFIGURACAO POS-REBOOT DO DC01 CONCLUIDA ===" -ForegroundColor Cyan
