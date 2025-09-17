# Verifica se esta sendo executado como Administrador
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Execute o PowerShell como Administrador."
    Break
}

# Lista de recursos RSAT relacionados a Active Directory, DNS, DHCP e Server Manager
$adFeatures = @(
    "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0",   # ADUC, ADAC, ADSI, etc.
    "Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0",   # GPMC
    "Rsat.Dns.Tools~~~~0.0.1.0",                      # DNS Manager
    "Rsat.Dhcp.Tools~~~~0.0.1.0",                     # DHCP Manager
    "Rsat.ServerManager.Tools~~~~0.0.1.0"             # Server Manager
)

foreach ($featureName in $adFeatures) {
    $feature = Get-WindowsCapability -Online | Where-Object { $_.Name -eq $featureName }

    if ($feature -and $feature.State -ne "Installed") {
        Write-Host "Instalando: $($feature.Name) ..." -ForegroundColor Cyan
        try {
            Add-WindowsCapability -Online -Name $feature.Name -ErrorAction Stop
            Write-Host "$($feature.Name) instalado com sucesso." -ForegroundColor Green
        }
        catch {
            Write-Warning "Falha ao instalar $($feature.Name): $_"
        }
    } else {
        Write-Host "$featureName ja esta instalado ou nao foi encontrado." -ForegroundColor Yellow
    }
}

Write-Host "`nInstalacao das ferramentas AD, DNS, DHCP e Server Manager concluida." -ForegroundColor Green

# Dicas apos instalacao:
# dsa.msc        -> Active Directory Users and Computers
# dssite.msc     -> Active Directory Sites and Services
# domain.msc     -> Active Directory Domains and Trusts
# gpmc.msc       -> Group Policy Management Console
# dnsmgmt.msc    -> DNS Manager
# dhcpmgmt.msc   -> DHCP Manager
# ServerManager.exe -> Server Manager
