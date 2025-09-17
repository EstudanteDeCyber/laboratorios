Write-Host "=== INICIANDO WINDOWS UPDATE AUTOMATICO ===".ToUpper()

if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "INSTALANDO PSWINDOWSUPDATE...".ToUpper()
    Install-PackageProvider -Name NuGet -Force -Scope AllUsers
    Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
}

Import-Module PSWindowsUpdate

do {
    Write-Host "`nBUSCANDO ATUALIZACOES DISPONIVEIS...".ToUpper()
    $updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot

    if ($updates) {
        Write-Host "INSTALANDO ATUALIZACOES...".ToUpper()
        Install-WindowsUpdate -AcceptAll -IgnoreReboot -AutoReboot
        Write-Host "AGUARDANDO REINICIALIZACAO AUTOMATICA SE NECESSARIO...".ToUpper()
        Start-Sleep -Seconds 30
    } else {
        Write-Host "NENHUMA ATUALIZACAO ENCONTRADA. O SISTEMA ESTA ATUALIZADO.".ToUpper()
    }
} while ($updates -ne $null -and $updates.Count -gt 0)

Write-Host "`n✅ PROCESSO DE ATUALIZACAO CONCLUIDO. NENHUMA ATUALIZACAO PENDENTE.".ToUpper()
