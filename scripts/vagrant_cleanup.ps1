Write-Host "Executando 'vagrant global-status --prune' para atualizar lista..." -ForegroundColor Cyan
vagrant global-status --prune | Out-Null

Write-Host "Obtendo lista atualizada de Vagrant VMs ativas..." -ForegroundColor Cyan

$vms = vagrant global-status | ForEach-Object {
    if ($_ -match '^\s*([a-f0-9]+)\s+\S+\s+\S+\s+\S+\s+(.+)$') {
        [PSCustomObject]@{
            Id = $matches[1]
            Directory = $matches[2].Trim()
        }
    }
} | Where-Object { $_ }

if (-not $vms) {
    Write-Host "Nenhuma VM válida encontrada no global-status." -ForegroundColor Yellow
    exit 0
}

foreach ($vm in $vms) {
    Write-Host "`nTentando destruir VM ID: $($vm.Id) no diretório: $($vm.Directory)" -ForegroundColor Yellow

    $vmDestroyed = $false

    if (Test-Path $vm.Directory) {
        Push-Location $vm.Directory
        try {
            $output = vagrant destroy -f 2>&1
            if ($output -match "VM not created" -or $output -match "not found") {
                Write-Host "Vagrant não reconhece a VM. Tentando destruir via VBoxManage..." -ForegroundColor DarkYellow
            } else {
                Write-Host "VM destruída com sucesso via Vagrant no diretório." -ForegroundColor Green
                $vmDestroyed = $true
            }
        }
        catch {
            Write-Host "Erro destruindo via Vagrant: $_" -ForegroundColor Red
        }
        Pop-Location
    } else {
        Write-Host "Diretório não existe. Tentando destruir via VBoxManage..." -ForegroundColor DarkYellow
    }

    if (-not $vmDestroyed) {
        # Tentativa de desligar e remover via VBoxManage
        try {
            $vmInfo = & VBoxManage list vms | Where-Object { $_ -match $vm.Id }
            if ($vmInfo) {
                Write-Host "Desligando e removendo via VBoxManage..." -ForegroundColor Cyan
                & VBoxManage controlvm $vm.Id poweroff 2>$null
                & VBoxManage unregistervm $vm.Id --delete
                Write-Host "VM destruída com sucesso via VBoxManage." -ForegroundColor Green
            } else {
                Write-Host "VM com ID $($vm.Id) não encontrada no VirtualBox. Pode já estar removida." -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "Erro ao destruir via VBoxManage: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nFim do script." -ForegroundColor Cyan
