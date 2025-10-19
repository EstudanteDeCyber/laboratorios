# Lista de VMs com nome e MAC
$vms = @(
    @{ Name = "dns1";        MAC = "080027BB0001" },
    @{ Name = "dns2";        MAC = "080027BB0002" },
    @{ Name = "samba-sftp";  MAC = "080027BB0003" },
    @{ Name = "webserver-webmin"; MAC = "080027BB0004" },
    @{ Name = "syslog-ntp";  MAC = "080027BB0005" },
    @{ Name = "ubuntu-desk"; MAC = "080027BB0009" },
    @{ Name = "windows10";   MAC = "080027BBDDE2" },
    @{ Name = "debian-n1";   MAC = "001122334458" },
    @{ Name = "debian-n2";   MAC = "001122334459" },
    @{ Name = "debian-n3";   MAC = "001122334460" },
    @{ Name = "firewall";    MAC = "080027AA0001" }
)

$hostOnlyName = "VirtualBox Host-Only Ethernet Adapter"
$infraNetwork = "infraopen_network"

# Funcao para escrever logs com timestamp
function Write-Log {
    param($Message)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
}

# Aguarda o Vagrant finalizar operacoes
Write-Log "Aguardando 10 segundos para garantir que o Vagrant finalizou o provisionamento..."
Start-Sleep -Seconds 10

# Verifica se o Vagrant ainda esta em execucao
Write-Log "Verificando se o Vagrant ainda esta ativo..."
$vagrantProcess = Get-Process -Name "vagrant" -ErrorAction SilentlyContinue
if ($vagrantProcess) {
    Write-Log "Processo do Vagrant ainda ativo. Aguardando mais 30 segundos..."
    Start-Sleep -Seconds 30
}

# Verifica se a rede host-only existe
try {
    $hostOnlyAdapters = VBoxManage list hostonlyifs | Select-String $hostOnlyName
    if (-not $hostOnlyAdapters) {
        Write-Log "Rede host-only '$hostOnlyName' nao encontrada. Criando..."
        VBoxManage hostonlyif create
        VBoxManage hostonlyif ipconfig "$hostOnlyName" --ip 192.168.56.1 --netmask 255.255.255.0
        Write-Log "Rede host-only '$hostOnlyName' criada."
    }
} catch {
    Write-Log "Erro ao verificar/criar rede host-only: $_"
    exit 1
}

# Obter VMs registradas
$registeredVMs = VBoxManage list vms | ForEach-Object {
    ($_ -split '"')[1]
}

# Configuracao das VMs
Write-Log "Iniciando configuracao das VMs..."
foreach ($vm in $vms) {
    $name = $vm.Name
    $mac  = $vm.MAC

    if ($registeredVMs -notcontains $name) {
        Write-Log "VM '$name' nao esta registrada. Pulando..."
        continue
    }

    # Verifica se a VM esta em execucao
    $isRunning = (VBoxManage list runningvms | Select-String $name) -ne $null
    if ($isRunning) {
        Write-Log "VM '$name' esta em execucao. Forcando parada..."
        try {
            VBoxManage controlvm $name poweroff
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Erro ao parar VM '$name'."
                continue
            }
            Write-Log "VM '$name' parada com sucesso."
            Start-Sleep -Seconds 5
        } catch {
            Write-Log "Erro ao parar VM '$name': $_"
            continue
        }
    }

    Write-Log "Configurando rede para VM: $name"
    try {
        if ($name -eq "firewall") {
            # Configuracao especifica para a firewall: NIC3 como host-only
            VBoxManage modifyvm $name --nic3 hostonly --hostonlyadapter3 "$hostOnlyName"
            VBoxManage modifyvm $name --nicpromisc3 allow-vms
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Erro ao configurar NIC3 para VM '$name'."
                continue
            }
            Write-Log "NIC3 configurada como Host-Only ($hostOnlyName)"
        } else {
            # Configuracao para outras VMs: NIC1 como intnet com MAC especifico
            VBoxManage modifyvm $name --macaddress1 $mac
            VBoxManage modifyvm $name --nicpromisc1 allow-vms
            VBoxManage modifyvm $name --nic1 intnet --intnet1 $infraNetwork
            VBoxManage modifyvm $name --nic2 none
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Erro ao configurar rede para VM '$name'."
                continue
            }
            Write-Log "NIC1: MAC $mac | intnet: $infraNetwork"
        }
    } catch {
        Write-Log "Erro ao configurar rede para VM '$name': $_"
        continue
    }

    # Religar a VM apos configuracao
    Write-Log "Iniciando VM: $name"
    try {
        VBoxManage startvm $name --type headless
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Erro ao iniciar VM '$name'."
            continue
        }
        Write-Log "VM '$name' iniciada com sucesso."
        Start-Sleep -Seconds 5
    } catch {
        Write-Log "Erro ao iniciar VM '$name': $_"
        continue
    }
}

Write-Log "Todas as configuracoes e inicializacoes foram concluidas (quando possivel)."