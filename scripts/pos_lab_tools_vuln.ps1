# Lista de VMs
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

# Obter VMs registradas
$registeredVMs = VBoxManage list vms | ForEach-Object {
    if ($_ -match '"') {
        ($_ -split '"')[1]
    }
}

# Obter VMs em execução
$runningVMs = VBoxManage list runningvms | ForEach-Object {
    if ($_ -match '"') {
        ($_ -split '"')[1]
    }
}

foreach ($vm in $vms) {
    $name = $vm.Name
    $mac = $vm.MAC

    # Verificar se a VM está registrada
    if ($registeredVMs -notcontains $name) {
        Write-Host "⚠️ VM '$name' não está registrada. Pulando..."
        Write-Host ""
        continue
    }

    # Se estiver ligada, desliga primeiro
    if ($runningVMs -contains $name) {
        Write-Host "⏻ Desligando VM '$name' antes de aplicar configurações..."
        VBoxManage controlvm $name poweroff
        # Aguardar até a VM desligar
        do {
            Start-Sleep -Seconds 3
            $runningVMs = VBoxManage list runningvms | ForEach-Object {
                if ($_ -match '"') {
                    ($_ -split '"')[1]
                }
            }
        } while ($runningVMs -contains $name)
        Write-Host "✅ VM '$name' foi desligada."
        Write-Host ""
    }

    Write-Host "🔧 Configurando VM '$name'..."
    if ($name -eq "Kali") {
        VBoxManage modifyvm $name --macaddress2 $mac
        VBoxManage modifyvm $name --nicpromisc2 allow-vms
        VBoxManage modifyvm $name --nic2 intnet --intnet2 $infraNetwork
        VBoxManage modifyvm $name --nicpromisc3 allow-vms
        VBoxManage modifyvm $name --nic3 hostonly --hostonlyadapter3 "$hostOnlyName"
        VBoxManage modifyvm $name --nic4 none
        Write-Host " → NIC2 configurada para intnet: $infraNetwork com modo promíscuo"
        Write-Host " → NIC3 (host-only) configurado com modo promíscuo: $hostOnlyName"
        Write-Host ""
    } elseif ($name -eq "Windows10") {
        VBoxManage modifyvm $name --nic1 intnet --intnet1 nat
        VBoxManage modifyvm $name --macaddress2 $mac
        VBoxManage modifyvm $name --nic2 intnet --intnet2 $infraNetwork
        VBoxManage modifyvm $name --nicpromisc2 allow-vms
        VBoxManage modifyvm $name --nicpromisc3 allow-vms
        VBoxManage modifyvm $name --nic3 hostonly --hostonlyadapter3 "$hostOnlyName"
        VBoxManage modifyvm $name --nic3 none
        VBoxManage modifyvm $name --nic4 none
        Write-Host " → NIC2 configurada para intnet: $infraNetwork com modo promíscuo"
        Write-Host " → NIC3 (host-only) configurado com modo promíscuo: $hostOnlyName"
        Write-Host ""
    } elseif ($name -eq "Metasploitable3-W2k8") {
        VBoxManage modifyvm $name --nic1 none
        VBoxManage modifyvm $name --macaddress2 $mac
        VBoxManage modifyvm $name --nic2 intnet --intnet2 $infraNetwork
        VBoxManage modifyvm $name --nicpromisc2 allow-vms
        VBoxManage modifyvm $name --nic3 none
        VBoxManage modifyvm $name --nic4 none
        Write-Host " → NIC1 desabilitada na VM '$name'"
        Write-Host " → NIC2 configurada para intnet: $infraNetwork com modo promíscuo"
        Write-Host ""
    } else {
        VBoxManage modifyvm $name --macaddress1 $mac
        VBoxManage modifyvm $name --nicpromisc1 allow-vms
        VBoxManage modifyvm $name --nic1 intnet --intnet1 $infraNetwork
        VBoxManage modifyvm $name --nic2 none
        VBoxManage modifyvm $name --nic3 none
        VBoxManage modifyvm $name --nic4 none
        Write-Host " → NIC1 configurada para intnet: $infraNetwork com modo promíscuo"
        Write-Host ""
    }

    # Ligar a VM novamente
    Write-Host "🚀 Ligando VM '$name'..."
    VBoxManage startvm $name --type headless
    Write-Host ""
}

# Iniciar Firewall, se necessário
if ($registeredVMs -contains "Debian11_Firewall") {
    $runningVMs = VBoxManage list runningvms | ForEach-Object {
        if ($_ -match '"') {
            ($_ -split '"')[1]
        }
    }
    if ($runningVMs -notcontains "Debian11_Firewall") {
        Write-Host "🔥 Debian11_Firewall iniciado com sucesso."
        VBoxManage startvm "Debian11_Firewall" --type headless
        Write-Host ""
    } else {
        Write-Host "ℹ️ Debian11_Firewall já está em execução."
        Write-Host ""
    }
} else {
    Write-Host "⚠️ Debian11_Firewall não está registrada."
    Write-Host ""
}

Write-Host "✅ Processo finalizado com sucesso."
Write-Host ""
