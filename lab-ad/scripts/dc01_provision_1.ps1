Write-Host "=== CONFIGURANDO NIC 'ETHERNET' COM IP ESTATICO E DNS ===".ToUpper()

$ipAddress = "10.10.10.20"
$prefixLength = 24
$gateway = "10.10.10.254"
$dnsServer = "10.10.10.20"

$nic = Get-NetAdapter -Name "Ethernet" -ErrorAction SilentlyContinue

if ($nic) {
    try {
        # REMOVE IP ANTERIOR
        Get-NetIPAddress -InterfaceAlias "Ethernet" -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false
        # RESETA DNS
        Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ResetServerAddresses
        # DEFINE IP/GATEWAY
        New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress $ipAddress -PrefixLength $prefixLength -DefaultGateway $gateway -ErrorAction Stop
        # DEFINE DNS
        Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $dnsServer
        Write-Host ("✅ NIC 'ETHERNET' CONFIGURADA COM IP $ipAddress, GATEWAY $gateway E DNS $dnsServer.").ToUpper()
    } catch {
        Write-Host ("❌ ERRO AO CONFIGURAR NIC: " + $_.Exception.Message).ToUpper()
    }
} else {
    Write-Host "❌ NIC 'ETHERNET' NAO ENCONTRADA. VERIFIQUE O NOME DA INTERFACE.".ToUpper()
}

# CONFIGURA SENHA DO MODO DE RESTAURACAO DO AD
$SafeModePassword = ConvertTo-SecureString "P@ssw0rd0123" -AsPlainText -Force

try {
    Write-Host "=== PROMOVENDO MAQUINA A DOMAIN CONTROLLER (AD DS) ===".ToUpper()
    Install-ADDSForest `
        -DomainName "lab.local" `
        -DomainNetbiosName "LAB" `
        -SafeModeAdministratorPassword $SafeModePassword `
        -InstallDns:$true `
        -Force:$true `
        -NoRebootOnCompletion:$false
    Write-Host "✅ AD DS INSTALADO E PROMOCAO INICIADA.".ToUpper()
} catch {
    Write-Host ("❌ ERRO AO PROMOVER AD DS: " + $_.Exception.Message).ToUpper()
}
