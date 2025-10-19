# ===============================
# clean_bloatware_total.ps1
# Remove o máximo de apps possível de forma segura,
# protege contra reinstalação e gera log.
# ===============================

# Exige execução como Administrador
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Execute o PowerShell como Administrador!"
    Exit 1
}

# Local para log de execução
$logFile = "$env:TEMP\clean_bloatware.log"
"--- Início: $(Get-Date) ---" | Out-File $logFile

# Apps removíveis (com nomes internos)
$appsParaRemover = @(
    "Microsoft.YourPhone",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsCamera",
    "Microsoft.ScreenSketch",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.XboxApp",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.BingNews",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.Maps",
    "Microsoft.People",
    "Microsoft.3DBuilder",
    "Microsoft.Paint", "Microsoft.MSPaint",
    "Microsoft.MixedReality.Portal",
    "Microsoft.Clipchamp.Clipchamp",
    "Microsoft.SkypeApp",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.Windows.Photos",
    "Microsoft.WindowsCommunicationsApps",  # Mail e Calendar
    "Microsoft.WindowsStore.RetailDemo", # eventualmente presente em Retail
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.Whiteboard",
    "Microsoft.Todos",
    "Microsoft.OutlookForWindows",
    "MicrosoftTeams"
)

Function Write-Log {
    param([string]$message)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time - $message" | Out-File $logFile -Append
}

Write-Host "`n--- Removendo bloatware (veja o log em $logFile) ---" -ForegroundColor Cyan
Write-Log "Iniciando remoção"

# 1) Remover do usuário atual
ForEach ($app in $appsParaRemover) {
    Write-Host "Removendo do usuário: $app"
    Write-Log "Tentando Remove-AppxPackage: $app"
    Get-AppxPackage -Name $app -ErrorAction SilentlyContinue | ForEach-Object {
        Try {
            Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop
            Write-Log "Removido usuário: $($app)"
        } Catch {
            Write-Log "Erro Remove-AppxPackage $($app): $($_.Exception.Message)"
        }
    }
}

# 2) Remover provisionados (novos usuários)
Write-Log "Removendo AppxProvisionedPackage"
ForEach ($app in $appsParaRemover) {
    Get-AppxProvisionedPackage -Online |
        Where-Object { $_.DisplayName -eq $app } |
        ForEach-Object {
            Try {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop
                Write-Log "Desprovisionado: $($app)"
            } Catch {
                Write-Log "Erro Remove-AppxProvisionedPackage $($app): $($_.Exception.Message)"
            }
        }
}

# 3) Prevenir reinstalação futura via registro
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned"
If (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
    Write-Log "Criado registry path $regPath"
}

ForEach ($app in $appsParaRemover) {
    Try {
        New-ItemProperty -Path $regPath -Name $app -PropertyType DWord -Value 1 -Force | Out-Null
        Write-Log "Protected deprovisioned: $($app)"
    } Catch {
        Write-Log "Erro registry property: $($app) - $($_.Exception.Message)"
    }
}

# 4) Política DisableConsumerFeatures
$storePol = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"
If (-not (Test-Path $storePol)) { New-Item -Path $storePol -Force | Out-Null }
Set-ItemProperty -Path $storePol -Name "DisableConsumerFeatures" -Value 1 -Type DWord
Write-Log "Set DisableConsumerFeatures = 1"

Write-Host "`n--- Remoção concluída. Reinicie o sistema. Veja o log em $logFile ---" -ForegroundColor Green
Write-Log "Fim: $(Get-Date)"
