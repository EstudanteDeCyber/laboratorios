# post_deploy_script_fixed.ps1

# Lista de VMs e MACs
$vms = @(
    @{ Name = "TPOT"     ; MAC = "080027BB4481" },
    @{ Name = "SIEM"     ; MAC = "080027BB4482" },
	@{ Name = "CLIENTE"  ; MAC = "080027BB4483" },	
    @{ Name = "ATTACKER" ; MAC = "080027BB4484" },
    @{ Name = "FIREWALL" ; MAC = "080027BB4485" }
)

function Get-RegisteredVMs {
    VBoxManage list vms 2>$null | ForEach-Object { ($_ -split '"')[1] }
}

function Get-RunningVMs {
    VBoxManage list runningvms 2>$null | ForEach-Object { ($_ -split '"')[1] }
}

function Wait-ForVM-PowerOff {
    param(
        [string]$Name,
        [int]$TimeoutSeconds = 60
    )
    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        $running = Get-RunningVMs
        if ($running -notcontains $Name) { return $true }
        Start-Sleep -Seconds 2
        $elapsed += 2
    }
    return $false
}

$registeredVMs = Get-RegisteredVMs
if (-not $registeredVMs) {
    Write-Host "NENHUMA VM REGISTRADA ENCONTRADA. VERIFIQUE O VBOXMANAGE." -ForegroundColor Yellow
    exit 1
}

# Primeiro: para cada VM, certificar-se de que está desligada e aplicar as configs
foreach ($vm in $vms) {
    $name = $vm.Name
    $mac  = $vm.MAC

    if ($registeredVMs -notcontains $name) {
        Write-Host ("VM '$name' NAO ESTA REGISTRADA. PULANDO...").ToUpper()
        continue
    }

    $runningVMs = Get-RunningVMs
    if ($runningVMs -contains $name) {
        Write-Host ("DESLIGANDO VM '$name' ANTES DE APLICAR CONFIGURACOES...").ToUpper()
        & VBoxManage controlvm $name poweroff 2>&1 | Write-Host
        $ok = Wait-ForVM-PowerOff -Name $name -TimeoutSeconds 60
        if (-not $ok) {
            Write-Host ("ERRO: TIMEOUT AO DESLIGAR VM '$name'. PULANDO...").ToUpper()
            continue
        } else {
            Write-Host ("VM '$name' FOI DESLIGADA.").ToUpper()
        }
    }

    Write-Host ("CONFIGURANDO VM '$name'...").ToUpper()

    # Rede específica por VM (substitui as chamadas hardcoded)
    switch ($name.ToLower()) {
        "tpot" {
            & VBoxManage modifyvm $name --nic1 intnet --intnet1 "DMZNet" --nicpromisc1 allow-vms 2>&1 | Write-Host
            break
        }
        "siem" {
            & VBoxManage modifyvm $name --nic1 intnet --intnet1 "LANNet" --nicpromisc1 allow-vms 2>&1 | Write-Host
            break
        }
        "cliente" {
            & VBoxManage modifyvm $name --nic1 intnet --intnet1 "LANNet" --nicpromisc1 allow-vms 2>&1 | Write-Host
            break
        }
        "attacker" {
            & VBoxManage modifyvm $name --nic1 hostonly --hostonlyadapter1 "VirtualBox Host-Only Ethernet Adapter" 2>&1 | Write-Host
            break
        }		
        "firewall" {
			& VBoxManage modifyvm $name --nic2 intnet --intnet2 "DMZNet" --nicpromisc2 allow-vms 2>&1 | Write-Host
			& VBoxManage modifyvm $name --nic3 intnet --intnet3 "LANNet" --nicpromisc3 allow-vms 2>&1 | Write-Host
            & VBoxManage modifyvm $name --nic4 hostonly --hostonlyadapter4 "VirtualBox Host-Only Ethernet Adapter" 2>&1 | Write-Host			
            break
        }
        default {
            Write-Host ("AVISO: Sem configuração de rede específica para VM '$name'. Usando padrao.").ToUpper()
        }
    }

    # Desativar som e USB
    & VBoxManage modifyvm $name --audio-enabled off 2>&1 | Write-Host
    & VBoxManage modifyvm $name --usb off 2>&1 | Write-Host
    & VBoxManage modifyvm $name --usbehci off 2>&1 | Write-Host
    & VBoxManage modifyvm $name --usbxhci off 2>&1 | Write-Host

    Write-Host ("CONFIGURACOES APLICADAS EM '$name'.").ToUpper()
}

# Opcional: iniciar todas as VMs configuradas (executar somente quando quiser que todas subam)
Write-Host "INICIANDO TODAS AS VMS CONFIGURADAS (HEADLESS)..." -ForegroundColor Cyan
foreach ($vm in $vms) {
    $name = $vm.Name
    if (Get-RegisteredVMs -contains $name) {
        Write-Host ("LIGANDO VM '$name'...").ToUpper()
        & VBoxManage startvm $name --type headless 2>&1 | Write-Host
    }
}

Write-Host "PROCESSO FINALIZADO COM SUCESSO." -ForegroundColor Green