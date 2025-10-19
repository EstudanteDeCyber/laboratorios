# LISTA DE VMS
$vms = @(
    @{ Name = "CLI01_LAB-IAM" ; MAC = "080027CC4432" },
    @{ Name = "IDP01_LAB-IAM" ; MAC = "080027CC4430" },
    @{ Name = "APPS_LAB-IAM" ; MAC = "080027CC4431" }	
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
    
    # Desativar NIC1, NIC3 e NIC4
    VBoxManage modifyvm $name --nic1 none
    Write-Host "NIC1 DESATIVADA".ToUpper()

    VBoxManage modifyvm $name --nic3 none
    Write-Host "NIC3 DESATIVADA".ToUpper()

    VBoxManage modifyvm $name --nic4 none
    Write-Host "NIC4 DESATIVADA".ToUpper()

    # NÃO TOCAR NA NIC2 EM HIPÓTESE ALGUMA

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