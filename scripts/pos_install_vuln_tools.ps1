# POS_INSTALL_LAB_TOOLS_VULN.PS1
# SCRIPT PARA CONFIGURAR VMS DO LABORATORIO DE FORMA AUTOMATIZADA

# LISTA DE VMS
$vms = @(
    @{ Name = "Docker-Tools" ; MAC = "080027BB0081" },
    @{ Name = "Kali" ; MAC = "080027BB0083" },
    @{ Name = "Windows10" ; MAC = "080027BB0084" },
    @{ Name = "Docker-Vuln" ; MAC = "080027BB0082" },
    @{ Name = "Metasploitable2" ; MAC = "080027BB0085" },
    @{ Name = "Metasploitable3" ; MAC = "080027BB0086" },
    @{ Name = "Meta3-Win" ; MAC = "080027BB0087" }
)

$infraNetwork = "EngRev_Malware_VulnLab"
$hostOnlyName = "VirtualBox Host-Only Ethernet Adapter"

# FUNCAO PARA OBTER VMS REGISTRADAS
function Get-RegisteredVMs {
    $result = @()
    $out = & VBoxManage list vms 2>$null
    if ($out) {
        $out | ForEach-Object {
            if ($_ -match '"') {
                $result += ($_ -split '"')[1]
            }
        }
    }
    return $result
}

# FUNCAO PARA OBTER VMS EM EXECUCAO
function Get-RunningVMs {
    $result = @()
    $out = & VBoxManage list runningvms 2>$null
    if ($out) {
        $out | ForEach-Object {
            if ($_ -match '"') {
                $result += ($_ -split '"')[1]
            }
        }
    }
    return $result
}

# OBTER ESTADO INICIAL DAS VMS
$registeredVMs = Get-RegisteredVMs
$runningVMs = Get-RunningVMs

foreach ($vm in $vms) {
    $name = $vm.Name
    $mac = $vm.MAC

    # VERIFICAR SE A VM ESTA REGISTRADA
    if ($registeredVMs -notcontains $name) {
        Write-Host "[AVISO] VM '$name' NAO ESTA REGISTRADA. PULANDO..."
        Write-Host ""
        continue
    }

    # ATUALIZAR LISTA DE VMS EM EXECUCAO
    $runningVMs = Get-RunningVMs

    # SE A VM ESTIVER LIGADA, DESLIGAR
    if ($runningVMs -contains $name) {
        Write-Host "[ INFO ] DESLIGANDO VM '$name' ANTES DE APLICAR CONFIGURACOES..."
        try {
            & VBoxManage controlvm $name poweroff 2>$null
        } catch {
            Write-Host "[ ERRO ] FALHA AO ENVIAR COMANDO DE DESLIGAMENTO PARA '$name': $_"
        }

        # AGUARDAR DESLIGAMENTO COM TIMEOUT
        $timeoutSec = 60
        $elapsed = 0
        do {
            Start-Sleep -Seconds 3
            $elapsed += 3
            $runningVMs = Get-RunningVMs
            if ($elapsed -ge $timeoutSec) {
                Write-Host "[ ERRO ] TIMEOUT AO AGUARDAR DESLIGAMENTO DA VM '$name' APOS $timeoutSec SEGUNDOS."
                break
            }
        } while ($runningVMs -contains $name)

        if ($runningVMs -notcontains $name) {
            Write-Host "[ OK ] VM '$name' FOI DESLIGADA."
        }
        Write-Host ""
    }

    # CONFIGURAR INTERFACES DE REDE
    Write-Host "[ INFO ] CONFIGURANDO VM '$name'..."

    try {
        switch ($name) {
            "Kali" {
                & VBoxManage modifyvm $name --macaddress2 $mac
                & VBoxManage modifyvm $name --nicpromisc2 allow-vms
                & VBoxManage modifyvm $name --nic2 intnet --intnet2 $infraNetwork
                & VBoxManage modifyvm $name --nicpromisc3 allow-vms
                & VBoxManage modifyvm $name --nic3 hostonly --hostonlyadapter3 "$hostOnlyName"
                & VBoxManage modifyvm $name --nic4 none
                Write-Host " -> [ OK ] NIC2 CONFIGURADA PARA INTNET: $infraNetwork COM MODO PROMISCUO"
                Write-Host " -> [ OK ] NIC3 HOST-ONLY CONFIGURADA: $hostOnlyName"
            }
            "Windows10" {
                & VBoxManage modifyvm $name --nic1 nat
                & VBoxManage modifyvm $name --macaddress2 $mac
                & VBoxManage modifyvm $name --nic2 intnet --intnet2 $infraNetwork
                & VBoxManage modifyvm $name --nicpromisc2 allow-vms
                & VBoxManage modifyvm $name --nicpromisc3 allow-vms
                & VBoxManage modifyvm $name --nic3 hostonly --hostonlyadapter3 "$hostOnlyName"
                & VBoxManage modifyvm $name --nic4 none
                Write-Host " -> [ OK ] NIC1 DEFINIDA COMO NAT"
                Write-Host " -> [ OK ] NIC2 CONFIGURADA PARA INTNET: $infraNetwork"
                Write-Host " -> [ OK ] NIC3 HOST-ONLY CONFIGURADA: $hostOnlyName"
            }
            "Metasploitable3" {
                & VBoxManage modifyvm $name --nic1 none
                & VBoxManage modifyvm $name --macaddress2 $mac
                & VBoxManage modifyvm $name --nic2 intnet --intnet2 $infraNetwork
                & VBoxManage modifyvm $name --nicpromisc2 allow-vms
                & VBoxManage modifyvm $name --nic3 none
                & VBoxManage modifyvm $name --nic4 none
                Write-Host " -> [ OK ] NIC1 DESABILITADA"
                Write-Host " -> [ OK ] NIC2 CONFIGURADA PARA INTNET: $infraNetwork COM MODO PROMISCUO"
            }
            "Meta3-Win" {
                & VBoxManage modifyvm $name --nic1 none
                & VBoxManage modifyvm $name --macaddress2 $mac
                & VBoxManage modifyvm $name --nic2 intnet --intnet2 $infraNetwork
                & VBoxManage modifyvm $name --nicpromisc2 allow-vms
                & VBoxManage modifyvm $name --nic3 hostonly --hostonlyadapter3 "$hostOnlyName"
                & VBoxManage modifyvm $name --nic4 none
                Write-Host " -> [ OK ] NIC1 DESABILITADA"
                Write-Host " -> [ OK ] NIC2 CONFIGURADA PARA INTNET: $infraNetwork COM MODO PROMISCUO"
                Write-Host " -> [ OK ] NIC3 HOST-ONLY CONFIGURADA: $hostOnlyName"
            }
            default {
                & VBoxManage modifyvm $name --macaddress1 $mac
                & VBoxManage modifyvm $name --nicpromisc1 allow-vms
                & VBoxManage modifyvm $name --nic1 intnet --intnet1 $infraNetwork
                & VBoxManage modifyvm $name --nic2 none
                & VBoxManage modifyvm $name --nic3 none
                & VBoxManage modifyvm $name --nic4 none
                Write-Host " -> [ OK ] NIC1 CONFIGURADA PARA INTNET: $infraNetwork COM MODO PROMISCUO"
            }
        }
    } catch {
        Write-Host "[ ERRO ] FALHA AO MODIFICAR VM '$name': $_"
        Write-Host ""
        continue
    }

    # LIGAR A VM NOVAMENTE
    Write-Host "[ INFO ] LIGANDO VM '$name'..."
    try {
        & VBoxManage startvm $name --type headless 2>$null
        Write-Host "[ OK ] VM '$name' INICIADA EM MODO HEADLESS."
    } catch {
        Write-Host "[ ERRO ] FALHA AO INICIAR VM '$name': $_"
    }
    Write-Host ""
}

Write-Host "[ OK ] PROCESSO FINALIZADO COM SUCESSO."
Write-Host ""