# Script PowerShell para desativar telemetria no Windows 10 e 11

# Este script tenta desativar várias configurações de telemetria no Windows 10 e 11.
# Execute-o com privilégios de administrador.

Function Set-PrivacySetting {
    Param (
        [string]$Path,
        [string]$Name,
        [string]$Value,
        [string]$Type = "DWord"
    )
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -ErrorAction SilentlyContinue
}

Write-Host "INICIANDO A DESATIVACAO DA TELEMETRIA..."

# 1. DESATIVAR TELEMETRIA VIA CONFIGURACOES (SETTINGS APP) - DADOS DE DIAGNOSTICO
Write-Host "DESATIVANDO DADOS DE DIAGNOSTICO OPCIONAIS..."
Set-PrivacySetting -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesEnabled" -Value 0
Set-PrivacySetting -Path "HKLM:\SOFTWARE\Microsoft\Windows\WindowsUpdate\UX" -Name "IsOptedIn" -Value 0
Set-PrivacySetting -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy\DiagnosticsAndFeedback" -Name "AllowTelemetry" -Value 0
Set-PrivacySetting -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0

Write-Host "DADOS DE DIAGNOSTICO OPCIONAIS DESATIVADOS."

# 2. DESATIVAR OUTROS DADOS DE DIAGNOSTICO (SPEECH, INKING & TYPING)
Write-Host "DESATIVANDO OUTROS DADOS DE DIAGNOSTICO (FALA, TINTA E DIGITACAO)..."
Set-PrivacySetting -Path "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" -Name "Has  Consented" -Value 0
Set-PrivacySetting -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictInkingAndTypingData" -Value 1
Set-PrivacySetting -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestedData" -Value 0

Write-Host "OUTROS DADOS DE DIAGNOSTICO DESATIVADOS."

# 3. PARAR RASTREAMENTO DE ATIVIDADES (ACTIVITY HISTORY)
Write-Host "PARANDO O RASTREAMENTO DE ATIVIDADES..."
Set-PrivacySetting -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy\ActivityHistory" -Name "EnableActivityFeed" -Value 0
Set-PrivacySetting -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy\ActivityHistory" -Name "PublishUserActivities" -Value 0
Set-PrivacySetting -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy\ActivityHistory" -Name "UploadUserActivities" -Value 0

Write-Host "RASTREAMENTO DE ATIVIDADES PARADO."

# 4. DESATIVAR RASTREADORES DE PUBLICIDADE (ADVERTISING TRACKERS)
Write-Host "DESATIVANDO RASTREADORES DE PUBLICIDADE..."
Set-PrivacySetting -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0
Set-PrivacySetting -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0

Write-Host "RASTREADORES DE PUBLICIDADE DESATIVADOS."

# 5. DESATIVAR RECURSO 'ENCONTRAR MEU DISPOSITIVO' (FIND MY DEVICE)
Write-Host "DESATIVANDO O RECURSO 'ENCONTRAR MEU DISPOSITIVO'..."
Set-PrivacySetting -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny"

Write-Host "RECURSO 'ENCONTRAR MEU DISPOSITIVO' DESATIVADO."

# 6. DESATIVAR TELEMETRIA VIA POLITICA DE GRUPO (GROUP POLICY)
Write-Host "DESATIVANDO TELEMETRIA VIA POLITICA DE GRUPO..."
Set-PrivacySetting -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
Set-PrivacySetting -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "CommercialID" -Value ""

Write-Host "TELEMETRIA VIA POLITICA DE GRUPO DESATIVADA."

# 7. DESATIVAR TELEMETRIA VIA PROMPT DE COMANDO (COMMAND PROMPT) / SERVICOS
Write-Host "DESATIVANDO SERVICOS DE TELEMETRIA..."
Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
Stop-Service -Name "dmwappushservice" -ErrorAction SilentlyContinue
Set-Service -Name "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue

Write-Host "SERVICOS DE TELEMETRIA DESATIVADOS."

# 8. BLOQUEAR DOMINIOS DE TELEMETRIA VIA ARQUIVO HOSTS
Write-Host "BLOQUEANDO DOMINIOS DE TELEMETRIA..."
$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
$telemetryDomains = @(
    "vortex.data.microsoft.com",
    "vortex-win.data.microsoft.com",
    "telecommand.telemetry.microsoft.com",
    "telecommand.telemetry.microsoft.com.nsatc.net",
    "oca.telemetry.microsoft.com",
    "oca.telemetry.microsoft.com.nsatc.net",
    "sqm.telemetry.microsoft.com",
    "sqm.telemetry.microsoft.com.nsatc.net",
    "watson.telemetry.microsoft.com",
    "watson.telemetry.microsoft.com.nsatc.net",
    "redir.metaservices.microsoft.com",
    "choice.microsoft.com",
    "choice.microsoft.com.nsatc.net",
    "df.telemetry.microsoft.com",
    "reports.wes.df.telemetry.microsoft.com",
    "wes.df.telemetry.microsoft.com",
    "services.wes.df.telemetry.microsoft.com",
    "sqm.df.telemetry.microsoft.com",
    "telemetry.microsoft.com",
    "watson.ppe.telemetry.microsoft.com",
    "telemetry.appex.bing.net",
    "telemetry.urs.microsoft.com",
    "telemetry.appex.bing.net:443",
    "settings-sandbox.data.microsoft.com",
    "vortex-sandbox.data.microsoft.com",
    "survey.watson.microsoft.com",
    "watson.live.com",
    "watson.microsoft.com",
    "statsfe2.ws.microsoft.com",
    "corpext.msitadfs.glbdns.microsoft.com",
    "compatexchange.cloudapp.net",
    "cs1.wpc.v0cdn.net",
    "a-0001.a-msedge.net",
    "statsfe2.update.microsoft.com.akadns.net",
    "sls.update.microsoft.com.akadns.net",
    "fe2.update.microsoft.com.akadns.net",
    "65.55.108.23",
    "65.39.117.230",
    "23.218.212.69",
    "134.170.30.202",
    "137.116.81.24",
    "204.79.197.200",
    "23.218.212.69"
)

foreach ($domain in $telemetryDomains) {
    if (-not (Select-String -Path $hostsFile -Pattern $domain -Quiet)) {
        Add-Content -Path $hostsFile -Value "0.0.0.0 $domain"
    }
}

Write-Host "DOMINIOS DE TELEMETRIA BLOQUEADOS."

# 9. REMOVER TAREFAS AGENDADAS DE TELEMETRIA
Write-Host "REMOVENDO TAREFAS AGENDADAS DE TELEMETRIA..."
$telemetryTasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Application Experience\StartupAppTask",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeip",
    "\Microsoft\Windows\Autochk\Proxy",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Windows\FeedbackDevices\Microsoft-Windows-FeedbackDevices-Events",
    "\Microsoft\Windows\FeedbackDevices\Microsoft-Windows-FeedbackDevices-Tasks",
    "\Microsoft\Windows\License Manager\License Manager Policy Refresh",
    "\Microsoft\Windows\PIX\PIX_Performance_Data_Collector",
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
    "\Microsoft\Windows\SettingSync\BackgroundSync",
    "\Microsoft\Windows\SettingSync\SettingSyncHost",
    "\Microsoft\Windows\SharedPC\Account Cleanup",
    "\Microsoft\Windows\Subscription\LicenseAcquisition",
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
    "\Microsoft\Windows\WindowsUpdate\Automatic App Update",
    "\Microsoft\Windows\WindowsUpdate\sihclient",
    "\Microsoft\Windows\WindowsUpdate\sihpostreboot"
)

foreach ($task in $telemetryTasks) {
    Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
}

Write-Host "TAREFAS AGENDADAS DE TELEMETRIA REMOVIDAS."

Write-Host "DESATIVACAO DA TELEMETRIA CONCLUIDA. REINICIE O COMPUTADOR PARA APLICAR TODAS AS ALTERACOES."



