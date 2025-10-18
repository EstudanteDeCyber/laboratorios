# LISTA DE VMS
$vms = @(
    @{ Name = "DC01_LAB-AD" ; MAC = "080027BB0081" },
    @{ Name = "SRV01_LAB-AD" ; MAC = "080027BB0082" },
    @{ Name = "CLI01_LAB-AD" ; MAC = "080027BB0083" }
)

$infraNetwork = "LAB_AD"
$hostOnlyName = "VirtualBox Host-Only Ethernet Adapter"

$registeredVMs = VBoxManage list vms | ForEach-Object { ($_ -split '"')[1] }
$runningVMs    = VBoxManage list runningvms | ForEach-Object { ($_ -split '"')[1] }

foreach ($vm in $vms) {
    $name = $vm.Name
    $mac  = $vm.MAC

    if ($registeredVMs -notcontains $name) {
        Write-Host ("VM '$name' NAO ESTA REGISTRADA. PULANDO...").ToUpper()
        continue
    }

    if ($runningVMs -contains $name) {
        Write-Host ("DESLIGANDO VM '$name' ANTES DE APLICAR CONFIGURACOES...").ToUpper()
        VBoxManage controlvm $name poweroff

        $timeout = 60
        $elapsed = 0
        do {
            Start-Sleep -Seconds 3
            $elapsed += 3
            $runningVMs = VBoxManage list runningvms | ForEach-Object { ($_ -split '"')[1] }
            if ($elapsed -ge $timeout) { break }
        } while ($runningVMs -contains $name)
        Write-Host ("VM '$name' FOI DESLIGADA.").ToUpper()
    }

    Write-Host ("CONFIGURANDO VM '$name'...").ToUpper()
    
    # Rede
    VBoxManage modifyvm $name --macaddress1 $mac
    VBoxManage modifyvm $name --nic1 intnet --intnet1 $infraNetwork --nicpromisc1 allow-vms
    Write-Host ("NIC1 CONFIGURADA PARA INTNET: $infraNetwork COM MAC: $mac").ToUpper()

    if ($name -eq "CLI01_LAB-AD") {
        VBoxManage modifyvm $name --nic2 hostonly --hostonlyadapter2 "$hostOnlyName" --nicpromisc2 allow-vms
        Write-Host ("NIC2 CONFIGURADA COMO HOST-ONLY ($hostOnlyName)").ToUpper()
    } else {
        VBoxManage modifyvm $name --nic2 none
        Write-Host "NIC2 DESATIVADA".ToUpper()
    }

    VBoxManage modifyvm $name --nic3 none
    VBoxManage modifyvm $name --nic4 none

    # Desativar som e USB
    VBoxManage modifyvm $name --audio none
    VBoxManage modifyvm $name --usb off
    VBoxManage modifyvm $name --usbehci off
    VBoxManage modifyvm $name --usbxhci off
    Write-Host "PLACA DE SOM E USB DESATIVADOS".ToUpper()

    Write-Host ("LIGANDO VM '$name'...").ToUpper()
    VBoxManage startvm $name --type headless
}

Write-Host "`nPROCESSO FINALIZADO COM SUCESSO.".ToUpper()