#Requires -RunAsAdministrator
# Para rodar em outra maquina qquer, abra o powershell como administrator e 
# rode primeiro: Set-ExecutionPolicy RemoteSigned
Write-Host "`n===> INICIANDO LIMPEZA AGRESSIVA DE BLOATWARE E CUSTOMIZACOES <===" -ForegroundColor Cyan

# =====================================================
# FUNÇÕES AUXILIARES
# =====================================================

# Helper: matar e reiniciar o Explorer de forma segura
function Restart-Explorer {
    Write-Host "[Explorer] Reiniciando Explorer..." -ForegroundColor DarkCyan
    try {
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process explorer.exe
        Start-Sleep -Seconds 2
    } catch {
        Write-Warning "Falha ao reiniciar Explorer: $($_.Exception.Message)"
    }
}

# Helper para definir configurações de Registro
Function Set-RegistryValue {
    Param (
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)]$Value,
        [string]$Type = "DWord"
    )
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -ErrorAction Stop
    } catch {
        Write-Warning "Falha ao definir registro '$Path\$Name': $($_.Exception.Message)"
    }
}

# Helper para criar atalhos (.lnk)
function New-Shortcut {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$TargetPath,
        [string]$Arguments = "",
        [string]$IconLocation = "",
        [string]$WorkingDirectory = ""
    )
    try {
        $ws = New-Object -ComObject WScript.Shell
        $sc = $ws.CreateShortcut($Path)
        $sc.TargetPath = $TargetPath
        if ($Arguments) { $sc.Arguments = $Arguments }
        if ($IconLocation) { $sc.IconLocation = $IconLocation }
        if ($WorkingDirectory) { $sc.WorkingDirectory = $WorkingDirectory }
        $sc.Save()
    } catch {
        Write-Warning "Falha ao criar atalho '$Path': $($_.Exception.Message)"
    }
}

# Helper para normalizar strings (remover acentos, etc.)
function Normalize-String {
    param([string]$s)
    if (-not $s) { return "" }
    $n = $s.Normalize([Text.NormalizationForm]::FormD)
    return ([regex]::Replace($n, "\p{Mn}", ""))
}

# Helper para pinar na barra de tarefas (Taskbar)
function Pin-ToTaskbar {
    param(
        [Parameter(Mandatory=$true)][string]$TargetPath
    )
    try {
        $tmpLnk = Join-Path $env:TEMP ("pin_" + [IO.Path]::GetFileNameWithoutExtension($TargetPath) + ".lnk")
        New-Shortcut -Path $tmpLnk -TargetPath $TargetPath

        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace((Split-Path $tmpLnk))
        $item = $folder.ParseName((Split-Path $tmpLnk -Leaf))

        if ($item) {
            foreach ($verb in $item.Verbs()) {
                $verbName = Normalize-String($verb.Name.ToString().ToLower())
                if ($verbName -match "pin to taskbar|barra de tarefas|taskleiste|barra de tareas|anheften|taskbar") {
                    try {
                        $verb.DoIt()
                        Write-Host " - Pinado na barra de tarefas: $TargetPath" -ForegroundColor DarkGreen
                        break
                    } catch {
                        Write-Warning "Falha ao executar 'Pin to Taskbar' para '$TargetPath': $($_.Exception.Message)"
                    }
                }
            }
        }
    } catch {
        Write-Warning "Falha ao pinar '$TargetPath' na barra de tarefas: $($_.Exception.Message)"
    } finally {
        if (Test-Path $tmpLnk) { Remove-Item $tmpLnk -Force -ErrorAction SilentlyContinue }
    }
}

# Helper para pinar no Menu Iniciar (Start Menu)
function Pin-ToStartMenu {
    param(
        [Parameter(Mandatory=$true)][string]$TargetPath
    )
    try {
        $tmpLnk = Join-Path $env:TEMP ("pin_start_" + [IO.Path]::GetFileNameWithoutExtension($TargetPath) + ".lnk")
        New-Shortcut -Path $tmpLnk -TargetPath $TargetPath

        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace((Split-Path $tmpLnk))
        $item = $folder.ParseName((Split-Path $tmpLnk -Leaf))

        if ($item) {
            foreach ($verb in $item.Verbs()) {
                $verbName = Normalize-String($verb.Name.ToString().ToLower())
                if ($verbName -match "pin to start|pinar no inicio|an start anheften") {
                    try {
                        $verb.DoIt()
                        Write-Host " - Pinado no Menu Iniciar: $TargetPath" -ForegroundColor DarkGreen
                        break
                    } catch {
                        Write-Warning "Falha ao executar 'Pin to Start' para '$TargetPath': $($_.Exception.Message)"
                    }
                }
            }
        }
    } catch {
        Write-Warning "Falha ao pinar '$TargetPath' no Menu Iniciar: $($_.Exception.Message)"
    } finally {
        if (Test-Path $tmpLnk) { Remove-Item $tmpLnk -Force -ErrorAction SilentlyContinue }
    }
}

# =====================================================
# FUNÇÕES PRINCIPAIS DE LIMPEZA E OTIMIZAÇÃO
# =====================================================

# Configurar Timezone
function Set-TimeZoneToSaoPaulo {
    Write-Host "`n[1] CONFIGURANDO TIMEZONE PARA AMERICA/SAO_PAULO..." -ForegroundColor Cyan
    try {
        tzutil /s "E. South America Standard Time"
        Write-Host "OK." -ForegroundColor Green
    } catch { Write-Warning "Falha ao configurar timezone: $($_.Exception.Message)" }
}

# Remover OneDrive (instalador clássico)
function Remove-OneDrive {
    Write-Host "`n[2] REMOVENDO ONEDRIVE..." -ForegroundColor Cyan
    try {
        taskkill /f /im OneDrive.exe 2>$null
        $paths = @("$env:SystemRoot\SysWOW64\OneDriveSetup.exe", "$env:SystemRoot\System32\OneDriveSetup.exe")
        foreach ($p in $paths) { if (Test-Path $p) { Start-Process $p "/uninstall" -Wait -ErrorAction SilentlyContinue } }
        Remove-Item "$env:UserProfile\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:LocalAppData\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:ProgramData\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "OK." -ForegroundColor Green
    } catch { Write-Warning "Falha ao remover OneDrive: $($_.Exception.Message)" }
}

# Remover Apps AppX + bloquear reinstalacao
function Remove-BloatwareApps {
    Write-Host "`n[3] REMOVENDO BLOATWARE (Appx para todos/atuais/provisionados)..." -ForegroundColor Cyan
    $appsParaRemover = @(
        # comuns
        "Microsoft.3DBuilder","Microsoft.BingNews","Microsoft.BingWeather","Microsoft.GetHelp",
        "Microsoft.Getstarted","Microsoft.Microsoft3DViewer","Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection","Microsoft.MixedReality.Portal","Microsoft.Office.OneNote","Microsoft.OneConnect","Microsoft.People","Microsoft.Print3D",
        "Microsoft.SkypeApp","Microsoft.Wallet","Microsoft.Whiteboard","Microsoft.WindowsCamera","Microsoft.WindowsFeedbackHub","Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder","Microsoft.Xbox.TCUI","Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay","Microsoft.XboxGamingOverlay","Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay","Microsoft.YourPhone","Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo","Microsoft.ScreenSketch","Microsoft.MicrosoftStickyNotes",
        "Microsoft.Todos","Microsoft.WindowsCommunicationsApps","Microsoft.Clipchamp.Clipchamp","Microsoft.OutlookForWindows","MicrosoftTeams",
        "Microsoft.549981C3F5F10","Microsoft.BioEnrollment","Microsoft.Windows.OOBENetworkConnectionFlow",
        "Microsoft.Windows.OOBENetworkCaptivePortal","MicrosoftWindows.UndockedDevKit",
        "Microsoft.Windows.ContentDeliveryManager","Microsoft.BingSearch","Microsoft.Windows.CapturePicker",
        "c5e2524a-ea46-4f67-841f-6a9465d9d515","Microsoft.Windows.ParentalControls","Microsoft.Windows.Apprep.ChxApp",
        "Microsoft.Windows.CallingShellApp","Microsoft.Windows.PeopleExperienceHost",
        "Windows.CBSPreview","NcsiUwpApp","Microsoft.Windows.XGpuEjectDialog",
        "Microsoft.XboxGameCallableUI","Microsoft.MicrosoftEdgeDevToolsClient",
        "Microsoft.Windows.AssignedAccessLockApp","1527c705-839a-4832-9118-54d4Bd6a0c89",
        "E2A4F912-2574-4A75-9BB0-0D023378592B","F46D4000-FD22-4DB4-AC8E-4E1DDDE828FE",
        "Microsoft.AsyncTextService","Microsoft.Windows.PinningConfirmationDialog",
        "Microsoft.ECApp","Microsoft.CredDialogHost","Microsoft.Windows.DevHome","Microsoft.WebpImageExtension","Microsoft.WebMediaExtensions",
        "Microsoft.VP9VideoExtensions","Microsoft.StorePurchaseApp","Microsoft.HEIFImageExtension",
        "Microsoft.Edge.GameAssist",
        # específicos prints
        "Microsoft.WindowsBackup","Microsoft.Copilot","Microsoft.WindowsCopilot","Microsoft.AICopilot","Microsoft.Windows.SnipAndSketch","Microsoft.MicrosoftEdge","Microsoft.MicrosoftEdgeDevToolsClient",


        # Acessórios (exceto Notepad, Explorer, Paint, Snipping Tool, Remote Desktop)
        "Microsoft.WindowsAlarms", # Alarms & Clock
        "Microsoft.WindowsCalculator", # Calculator
        "Microsoft.Windows.Photos", # Photos
        "Microsoft.MSPaint", # Paint (removido, pois o usuário pediu para manter)
        "Microsoft.ScreenSketch", # Snip & Sketch (removido, pois o usuário pediu para manter)
        "Microsoft.Windows.RemoteDesktop", # Remote Desktop (removido, pois o usuário pediu para manter)
        "Microsoft.Windows.StickyNotes", # Sticky Notes
        "Microsoft.Windows.VoiceRecorder", # Voice Recorder
        "Microsoft.Windows.Maps", # Maps
        "Microsoft.Windows.People", # People
        "Microsoft.ZuneVideo", # Movies & TV
        "Microsoft.ZuneMusic", # Groove Music
        "Microsoft.BingNews", # News
        "Microsoft.BingWeather", # Weather
        "Microsoft.SolitaireCollection", # Solitaire Collection
        "Microsoft.XboxApp", # Xbox
        "Microsoft.XboxGameOverlay", # Xbox Game Bar
        "Microsoft.XboxGamingOverlay", # Xbox Game Bar
        "Microsoft.XboxIdentityProvider", # Xbox Identity Provider
        "Microsoft.XboxSpeechToTextOverlay", # Xbox Speech to Text Overlay
        "Microsoft.YourPhone", # Your Phone
        "Microsoft.GetHelp", # Get Help
        "Microsoft.Getstarted", # Get Started
        "Microsoft.Microsoft3DViewer", # 3D Viewer
        "Microsoft.MicrosoftOfficeHub", # Office
        "Microsoft.MixedReality.Portal", # Mixed Reality Portal
        "Microsoft.Print3D", # Print 3D
        "Microsoft.SkypeApp", # Skype
        "Microsoft.Wallet", # Wallet
        "Microsoft.Whiteboard", # Whiteboard
        "Microsoft.WindowsFeedbackHub", # Feedback Hub
        "Microsoft.WindowsCommunicationsApps", # Mail and Calendar
        "Microsoft.Todos", # To Do
        "Microsoft.Clipchamp.Clipchamp", # Clipchamp
        "Microsoft.OutlookForWindows", # Outlook
        "MicrosoftTeams", # Teams
        # Windows System (exceto Command Prompt, Control Panel, Run, File Explorer)
        "Microsoft.Windows.NarratorQuickStart", # Narrator QuickStart
        "Microsoft.Windows.ParentalControls", # Parental Controls
        "Microsoft.Windows.Apprep.ChxApp", # App Resolver UX
        "Microsoft.Windows.CallingShellApp", # Calling Shell App
        "Microsoft.Windows.PeopleExperienceHost", # People Experience Host
        "Windows.CBSPreview", # Windows CBS Preview
        "NcsiUwpApp", # NCSI UWP App
        "Microsoft.Windows.XGpuEjectDialog", # XGPU Eject Dialog
        "Microsoft.XboxGameCallableUI", # Xbox Game Callable UI
        "Microsoft.MicrosoftEdgeDevToolsClient", # Edge DevTools Client
        "Microsoft.Windows.AssignedAccessLockApp", # Assigned Access Lock App
        "Microsoft.AsyncTextService", # Async Text Service
        "Microsoft.Windows.PinningConfirmationDialog", # Pinning Confirmation Dialog
        "Microsoft.ECApp", # EC App
        "Microsoft.CredDialogHost", # Credential Dialog Host
        "Microsoft.Windows.DevHome", # Dev Home
        "Microsoft.WebpImageExtension", # WebP Image Extension
        "Microsoft.WebMediaExtensions", # Web Media Extensions
        "Microsoft.VP9VideoExtensions", # VP9 Video Extensions
        "Microsoft.StorePurchaseApp", # Store Purchase App
        "Microsoft.HEIFImageExtension", # HEIF Image Extension
        "Microsoft.Edge.GameAssist", # Edge Game Assist
        # Acessibilidade (remover tudo)
        "Microsoft.Windows.Narrator",
        "Microsoft.Windows.Magnifier",
        "Microsoft.Windows.OnScreenKeyboard",
        "Microsoft.Windows.StickyKeys",
        "Microsoft.Windows.FilterKeys",
        "Microsoft.Windows.ToggleKeys"
    )
   $padroesExtras = "copilot|xbox|bing|zune|clipchamp|onenote|teams|edge|store|news|weather|solitaire|cortana|office|maps|camera|people|phone|calendar|photos|feedback|alarm|todo|notas|media|vp9|heif|webp|outlook|skype|copilot|windowsbackup|3dbuilder|3dviewer|mixedreality|print3d|wallet|whiteboard|gethelp|getstarted|microsoftofficehub|microsoftedgedevtoolsclient|assignedaccesslockapp|asynctextservice|pinningconfirmationdialog|ecapp|creddialoghost|devhome|gameassist|parentalcontrols|apprep|callingshellapp|peopleexperiencehost|cbspreview|ncsiuwpapp|xgpuejectdialog|xboxgamecallableui|accessibility|narrator|magnifier|onscreenkeyboard|stickykeys|filterkeys|togglekeys|windowsaccessories|windowssystem|easeofaccess|edge|mspaint|snip|sketch"
    $exceptions = @(
        "Microsoft.Windows.Notepad",
        "Microsoft.Windows.Explorer",
        "Microsoft.MSPaint",
        "Microsoft.ScreenSketch",
        "Microsoft.Windows.RemoteDesktop",
        "Microsoft.Windows.CommandPrompt",
        "Microsoft.Windows.ControlPanel",
        "Microsoft.Windows.Run",
        "Microsoft.Windows.FileExplorer"
    )

    # Filtrar exceções da lista de remoção
    $appsParaRemover = $appsParaRemover | Where-Object { $_ -notin $exceptions }

    # Adicionar padrões para as exceções que não devem ser removidas
    $padroesExtras = $padroesExtras -replace "paint|screensketch|remotedesktop|commandprompt|controlpanel|run|fileexplorer", ""


    # Funções auxiliares para remoção de AppX
    function Remove-AppxPackageSafe {
        param([string]$PackageFullName, [switch]$AllUsers)
        try {
            if ($AllUsers) {
                Remove-AppxPackage -Package $PackageFullName -AllUsers -ErrorAction Stop | Out-Null
            } else {
                Remove-AppxPackage -Package $PackageFullName -ErrorAction Stop | Out-Null
            }
            Write-Host " - Removido com sucesso: $PackageFullName" -ForegroundColor DarkGreen
        } catch [System.Exception] {
            if ($_.Exception.HResult -eq -2147024894) { # 0x80070002 - The system cannot find the file specified (often for already removed packages)
                # Pacote já removido ou não encontrado, o que é bom. Silenciar.
            } elseif ($_.Exception.HResult -eq -2147009772) { # 0x80073CF4 - Package was not found
                # Pacote não encontrado, o que é bom. Silenciar.
            } elseif ($_.Exception.HResult -eq -2147009297) { # 0x80073D0F - The package could not be installed because a higher version of this package is already installed.
                # Versão mais recente já instalada, o que é bom. Silenciar.
            } else {
                Write-Host " - Nao foi possivel remover: $PackageFullName" -ForegroundColor DarkYellow
            }
        }
    }

    function Remove-AppxProvisionedPackageSafe {
        param([string]$PackageName)
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $PackageName -ErrorAction Stop | Out-Null
            Write-Host " - Desprovisionado com sucesso: $PackageName" -ForegroundColor DarkGreen
        } catch [System.Exception] {
            if ($_.Exception.Message -like "*0x80073cf2*") {
                // Pacote não encontrado, o que é bom. Silenciar.
            } else {
                Write-Host " - Nao foi possivel desprovisionar: $PackageName" -ForegroundColor DarkYellow
            }
        }
    }

    # Remover para todos os usuários (instalado)
    Get-AppxPackage -AllUsers | Where-Object { $_.Name -in $appsParaRemover -or $_.Name -match $padroesExtras } |
        Sort-Object PackageFullName -Unique |
        ForEach-Object {
            Write-Host " - Tentando remover (AllUsers): $($_.Name)" -ForegroundColor Yellow
            Remove-AppxPackageSafe -PackageFullName $_.PackageFullName -AllUsers
        }

    # Remover para o usuário atual
    Get-AppxPackage | Where-Object { $_.Name -match $padroesExtras -or $_.Name -in $appsParaRemover } |
        ForEach-Object {
            Write-Host " - Tentando remover (Atual): $($_.Name)" -ForegroundColor Yellow
            Remove-AppxPackageSafe -PackageFullName $_.PackageFullName
        }

    # Desprovisionar (para novos usuários)
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -match $padroesExtras -or $_.DisplayName -in $appsParaRemover } |
        ForEach-Object {
            Write-Host " - Tentando desprovisionar: $($_.DisplayName)" -ForegroundColor Yellow
            Remove-AppxProvisionedPackageSafe -PackageName $_.PackageName
        }

    # Bloquear reinstalação via Registro
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    foreach ($app in $appsParaRemover) { Set-RegistryValue -Path $regPath -Name $app -Value 1 -Type "DWord" }
    Write-Host "OK." -ForegroundColor Green
}

# Aplicar Políticas de Sistema
function Apply-SystemPolicies {
    Write-Host "`n[4] APLICANDO POLITICAS DE SISTEMA..." -ForegroundColor Cyan
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableConsumerFeatures" -Value 1 -Type "DWord"
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableStoreApp" -Value 1 -Type "DWord"
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "AutoDownload" -Value 2 -Type "DWord"
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "RemoveWindowsStore" -Value 1 -Type "DWord"
    Write-Host "OK." -ForegroundColor Green
}

# Desativar Telemetria e Coleta de Dados
function Disable-Telemetry {
    Write-Host "`n[5] DESATIVANDO TELEMETRIA E COLETA DE DADOS..." -ForegroundColor Cyan

    # 1. Configurações de Diagnóstico e Feedback
    Write-Host " - Desativando Dados de Diagnóstico Opcionais..." -ForegroundColor DarkCyan
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesEnabled" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\WindowsUpdate\UX" -Name "IsOptedIn" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy\DiagnosticsAndFeedback" -Name "AllowTelemetry" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0

    # 2. Outros Dados de Diagnóstico (Fala, Tinta e Digitação)
    Write-Host " - Desativando Outros Dados de Diagnóstico (Fala, Tinta e Digitação)..." -ForegroundColor DarkCyan
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" -Name "Has Consented" -Value 0
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictInkingAndTypingData" -Value 1
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestedData" -Value 0

    # 3. Rastreamento de Atividades (Activity History)
    Write-Host " - Parando o Rastreamento de Atividades..." -ForegroundColor DarkCyan
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy\ActivityHistory" -Name "EnableActivityFeed" -Value 0
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy\ActivityHistory" -Name "PublishUserActivities" -Value 0
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy\ActivityHistory" -Name "UploadUserActivities" -Value 0

    # 4. Rastreadores de Publicidade (Advertising Trackers)
    Write-Host " - Desativando Rastreadores de Publicidade..." -ForegroundColor DarkCyan
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0

    # 5. Recurso 'Encontrar Meu Dispositivo' (Find My Device)
    Write-Host " - Desativando o Recurso 'Encontrar Meu Dispositivo'..." -ForegroundColor DarkCyan
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny"

    # 6. Telemetria via Política de Grupo (Group Policy)
    Write-Host " - Desativando Telemetria via Política de Grupo..." -ForegroundColor DarkCyan
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "CommercialID" -Value ""

    # 7. Serviços de Telemetria
    Write-Host " - Desativando Serviços de Telemetria..." -ForegroundColor DarkCyan
    try {
        Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name "dmwappushservice" -ErrorAction SilentlyContinue
        Set-Service -Name "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
    } catch { Write-Warning "Falha ao desativar serviços de telemetria: $($_.Exception.Message)" }

    # 8. Bloquear Domínios de Telemetria via Arquivo Hosts
    Write-Host " - Bloqueando Domínios de Telemetria..." -ForegroundColor DarkCyan
    $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    $telemetryDomains = @(
        "vortex.data.microsoft.com", "vortex-win.data.microsoft.com",
        "telecommand.telemetry.microsoft.com", "telecommand.telemetry.microsoft.com.nsatc.net",
        "oca.telemetry.microsoft.com", "oca.telemetry.microsoft.com.nsatc.net",
        "sqm.telemetry.microsoft.com", "sqm.telemetry.microsoft.com.nsatc.net",
        "watson.telemetry.microsoft.com", "watson.telemetry.microsoft.com.nsatc.net",
        "redir.metaservices.microsoft.com", "choice.microsoft.com",
        "choice.microsoft.com.nsatc.net", "df.telemetry.microsoft.com",
        "reports.wes.df.telemetry.microsoft.com", "wes.df.telemetry.microsoft.com",
        "services.wes.df.telemetry.microsoft.com", "sqm.df.telemetry.microsoft.com",
        "telemetry.microsoft.com", "watson.ppe.telemetry.microsoft.com",
        "telemetry.appex.bing.net", "telemetry.urs.microsoft.com",
        "telemetry.appex.bing.net:443", "settings-sandbox.data.microsoft.com",
        "vortex-sandbox.data.microsoft.com", "survey.watson.microsoft.com",
        "watson.live.com", "watson.microsoft.com",
        "statsfe2.ws.microsoft.com", "corpext.msitadfs.glbdns.microsoft.com",
        "compatexchange.cloudapp.net", "cs1.wpc.v0cdn.net",
        "a-0001.a-msedge.net", "statsfe2.update.microsoft.com.akadns.net",
        "sls.update.microsoft.com.akadns.net", "fe2.update.microsoft.com.akadns.net",
        "65.55.108.23", "65.39.117.230", "23.218.212.69",
        "134.170.30.202", "137.116.81.24", "204.79.197.200",
        "23.218.212.69"
    )

    foreach ($domain in $telemetryDomains) {
        try {
            if (-not (Select-String -Path $hostsFile -Pattern $domain -Quiet)) {
                Add-Content -Path $hostsFile -Value "0.0.0.0 $domain"
                Write-Host "   - Adicionado ao hosts: 0.0.0.0 $domain" -ForegroundColor DarkCyan
            }
        } catch { Write-Warning "Falha ao adicionar '$domain' ao hosts: $($_.Exception.Message)" }
    }

    # 9. Remover Tarefas Agendadas de Telemetria
    Write-Host " - Removendo Tarefas Agendadas de Telemetria..." -ForegroundColor DarkCyan
    $telemetryTasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\StartupAppTask",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\Customer Experience Program\KernelCeip",
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
        try {
            Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "   - Removida tarefa agendada: $task" -ForegroundColor DarkCyan
        } catch { Write-Warning "Falha ao remover tarefa agendada '$task': $($_.Exception.Message)" }
    }
    Write-Host "OK." -ForegroundColor Green
}

# Desativar News and Interests
function Disable-NewsAndInterests {
    Write-Host "`n[6] DESATIVANDO NEWS AND INTERESTS..." -ForegroundColor Cyan
    try {
        Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds" -Value 0 -Type "DWord"
        Write-Host "OK." -ForegroundColor Green
    } catch { Write-Warning "Falha ao desativar News and Interests: $($_.Exception.Message)" }
}

# Desativar Cortana
function Disable-Cortana {
    Write-Host "`n[7] DESATIVANDO CORTANA..." -ForegroundColor Cyan
    try {
        Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -Type "DWord"
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0 -Type "DWord"
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -Type "DWord"
        Write-Host "OK." -ForegroundColor Green
    } catch { Write-Warning "Falha ao desativar Cortana: $($_.Exception.Message)" }
}

# Desativar Game Bar
function Disable-GameBar {
    Write-Host "`n[8] DESATIVANDO GAME BAR..." -ForegroundColor Cyan
    try {
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Type "DWord"
        Set-RegistryValue -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type "DWord"
        Write-Host "OK." -ForegroundColor Green
    } catch { Write-Warning "Falha ao desativar Game Bar: $($_.Exception.Message)" }
}

# Desativar SmartScreen
function Disable-SmartScreen {
    Write-Host "`n[9] DESATIVANDO SMARTSCREEN..." -ForegroundColor Cyan
    try {
        Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SmartScreenEnabled" -Name "SmartScreenEnabled" -Value "Off" -Type "String"
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" -Name "EnableWebContentEvaluation" -Value 0 -Type "DWord"
        Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Value 0 -Type "DWord"
        Write-Host "OK." -ForegroundColor Green
    } catch { Write-Warning "Falha ao desativar SmartScreen: $($_.Exception.Message)" }
}

# Desativar Notificações e Dicas
function Disable-NotificationsAndTips {
    Write-Host "`n[10] DESATIVANDO NOTIFICACOES E DICAS..." -ForegroundColor Cyan
    try {
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 0 -Type "DWord"
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338393Enabled" -Value 0 -Type "DWord"
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0 -Type "DWord"
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0 -Type "DWord"
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type "DWord"
        Write-Host "OK." -ForegroundColor Green
    } catch { Write-Warning "Falha ao desativar notificações e dicas: $($_.Exception.Message)" }
}

# Desativar Botão de Visualização de Tarefas (Task View Button)
function Disable-TaskViewButton {
    Write-Host "`n[11] DESATIVANDO BOTAO DE VISUALIZACAO DE TAREFAS..." -ForegroundColor Cyan
    try {
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Type "DWord"
        # Para todos os usuários e Default
        $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin @("Default","Public","All Users","DefaultAppPool","Default User") }
        foreach ($u in $users) {
            $hive = Join-Path $u.FullName "NTUSER.DAT"
            if (Test-Path $hive) {
                $alias = ("TempHiveTV_" + ($u.Name -replace "[^A-Za-z0-9_]", "_"))
                try {
                    reg unload "HKU\$alias" 2>$null | Out-Null
                    if (reg load "HKU\$alias" "$hive" 2>$null) {
                        Set-ItemProperty -LiteralPath "Registry::HKU\$alias\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Force -ErrorAction Stop
                    }
                } finally {
                    reg unload "HKU\$alias" 2>$null | Out-Null
                }
            }
        }
        $defaultNtUserDat = "C:\Users\Default\NTUSER.DAT"
        if (Test-Path $defaultNtUserDat) {
            try {
                reg unload HKU\TempHiveTVDefault 2>$null | Out-Null
                if (reg load HKU\TempHiveTVDefault "$defaultNtUserDat" 2>$null) {
                    Set-ItemProperty -LiteralPath "Registry::HKU\TempHiveTVDefault\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Force -ErrorAction Stop
                }
            } finally {
                reg unload HKU\TempHiveTVDefault 2>$null | Out-Null
            }
        }
        Write-Host "OK." -ForegroundColor Green
    } catch { Write-Warning "Falha ao desativar botão de visualização de tarefas: $($_.Exception.Message)" }
}

# Limpar Start Menu (tiles/pins)
function Clear-StartMenuPins {
    Write-Host "`n[12] LIMPANDO PINS DO MENU INICIAR (Todos + Default)..." -ForegroundColor Cyan

    try {
        Remove-Item "$env:LocalAppData\Microsoft\Windows\Shell\DefaultLayouts.xml" -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:LocalAppData\Microsoft\Windows\Shell\LayoutModification.xml" -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:LocalAppData\TileDataLayer" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:LocalAppData\Microsoft\Windows\CloudStore" -Recurse -Force -ErrorAction SilentlyContinue

        $xmlStart = @"
<LayoutModificationTemplate xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification"
    xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout"
    xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout"
    Version="1">
  <CustomLayout>
    <defaultlayout:StartLayout>
      
    </defaultlayout:StartLayout>
  </CustomLayout>
</LayoutModificationTemplate>
"@

        $defaultShell = "C:\Users\Default\AppData\Local\Microsoft\Windows\Shell"
        New-Item -Path $defaultShell -ItemType Directory -Force | Out-Null
        $xmlStart | Out-File -FilePath (Join-Path $defaultShell "LayoutModification.xml") -Encoding UTF8 -Force

        $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin @("Default","Public","All Users","DefaultAppPool","Default User") }
        foreach ($u in $users) {
            $shellPath = Join-Path $u.FullName "AppData\Local\Microsoft\Windows\Shell"
            $cloudPath = Join-Path $u.FullName "AppData\Local\Microsoft\Windows\CloudStore"
            $tilePath  = Join-Path $u.FullName "AppData\Local\TileDataLayer"
            Remove-Item "$shellPath\DefaultLayouts.xml" -Force -ErrorAction SilentlyContinue
            Remove-Item "$shellPath\LayoutModification.xml" -Force -ErrorAction SilentlyContinue
            Remove-Item $cloudPath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $tilePath  -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Host "OK." -ForegroundColor Green
    } catch { Write-Warning "Falha ao limpar pins do Menu Iniciar: $($_.Exception.Message)" }
}

# Configurar Teclado BR ABNT2
function Set-KeyboardToBRABNT2 {
    Write-Host "`n[13] CONFIGURANDO TECLADO BR ABNT2..." -ForegroundColor Cyan
    try {
        Set-WinSystemLocale pt-BR
        Set-WinUserLanguageList -LanguageList pt-BR -Force
        Set-RegistryValue -Path "HKCU:\Keyboard Layout\Preload" -Name 1 -Value "00000416" -Type "String"
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\CTF\LangBar" -Name "ShowStatus" -Value 3 -Type "DWord"

        $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin @("Default","Public","All Users","DefaultAppPool","Default User") }
        foreach ($u in $users) {
            $hive = Join-Path $u.FullName "NTUSER.DAT"
            if (Test-Path $hive) {
                $alias = ("TempHiveKB_" + ($u.Name -replace "[^A-Za-z0-9_]", "_"))
                try {
                    reg unload "HKU\$alias" 2>$null | Out-Null
                    if (reg load "HKU\$alias" "$hive" 2>$null) {
                        Set-ItemProperty -LiteralPath "Registry::HKU\$alias\Keyboard Layout\Preload" -Name 1 -Value "00000416" -Type String -Force -ErrorAction Stop
                        Set-ItemProperty -LiteralPath "Registry::HKU\$alias\Software\Microsoft\CTF\LangBar" -Name "ShowStatus" -Value 3 -Type DWord -Force -ErrorAction Stop
                    }
                } finally {
                    reg unload "HKU\$alias" 2>$null | Out-Null
                }
            }
        }

        $defaultNtUserDat = "C:\Users\Default\NTUSER.DAT"
        if (Test-Path $defaultNtUserDat) {
            try {
                reg unload HKU\TempHiveKBDefault 2>$null | Out-Null
                if (reg load HKU\TempHiveKBDefault "$defaultNtUserDat" 2>$null) {
                    Set-ItemProperty -LiteralPath "Registry::HKU\TempHiveKBDefault\Keyboard Layout\Preload" -Name 1 -Value "00000416" -Type String -Force -ErrorAction Stop
                    Set-ItemProperty -LiteralPath "Registry::HKU\TempHiveKBDefault\Software\Microsoft\CTF\LangBar" -Name "ShowStatus" -Value 3 -Type DWord -Force -ErrorAction Stop
                }
            } finally {
                reg unload HKU\TempHiveKBDefault 2>$null | Out-Null
            }
        }
        Write-Host "OK." -ForegroundColor Green
    } catch { Write-Warning "Falha ao configurar teclado: $($_.Exception.Message)" }
}

# Resetar Taskband (para refletir .lnk)
function Reset-Taskband-ForAllUsers {
    Write-Host "`n[14] RESETANDO CACHE DA TASKBAR (Taskband)..." -ForegroundColor Cyan

    try {
        # Usuario atual
        Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Recurse -ErrorAction SilentlyContinue

        # Hives carregados
        $sids = [Microsoft.Win32.Registry]::Users.GetSubKeyNames()
        foreach ($sid in $sids) {
            if ($sid -match "S-1-5-21-") {
                Remove-Item -Path "HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Recurse -ErrorAction SilentlyContinue
            }
        }

        # Perfis offline
        $users = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin @("Default","Public","All Users","DefaultAppPool","Default User") }
        foreach ($u in $users) {
            $hive = Join-Path $u.FullName "NTUSER.DAT"
            if (Test-Path $hive) {
                $alias = ("TempHiveTB_" + ($u.Name -replace "[^A-Za-z0-9_]", "_"))
                try {
                    reg unload "HKU\$alias" 2>$null | Out-Null
                    if (reg load "HKU\$alias" "$hive" 2>$null) {
                        Remove-Item -Path "HKU:\$alias\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Recurse -ErrorAction SilentlyContinue
                    }
                } finally {
                    reg unload "HKU\$alias" 2>$null | Out-Null
                }
            }
        }

        # Default
        $defaultNtUserDat = "C:\Users\Default\NTUSER.DAT"
        if (Test-Path $defaultNtUserDat) {
            try {
                reg unload HKU\TempHiveTBDefault 2>$null | Out-Null
                if (reg load HKU\TempHiveTBDefault "$defaultNtUserDat" 2>$null) {
                    Remove-Item -Path "HKU:\TempHiveTBDefault\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Recurse -ErrorAction SilentlyContinue
                }
            } finally {
                reg unload HKU\TempHiveTBDefault 2>$null | Out-Null
            }
        }
        Write-Host "OK." -ForegroundColor Green
    } catch { Write-Warning "Falha ao resetar cache da Taskbar: $($_.Exception.Message)" }
}

# Pinar itens essenciais na barra de tarefas e Menu Iniciar
function Pin-EssentialItems {
    Write-Host "`n[15] PINANDO ITENS ESSENCIAIS NA BARRA DE TAREFAS E MENU INICIAR..." -ForegroundColor Cyan

    $itemsToPin = @(
        "$env:windir\System32\cmd.exe",
        "$env:windir\System32\notepad.exe",
        "$env:windir\explorer.exe"
    )

    foreach ($item in $itemsToPin) {
        Pin-ToTaskbar -TargetPath $item
    
    }

    # Remover Edge/Store da barra de tarefas se reaparecerem
    $taskbarPinsPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    if (Test-Path $taskbarPinsPath) {
        Get-ChildItem $taskbarPinsPath -Filter "*Edge*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem $taskbarPinsPath -Filter "*Store*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    Write-Host "OK." -ForegroundColor Green
}

# Instalar Tarefa Agendada para manter pins
function Install-LogonFixTaskbarScheduledTask {
    Write-Host "`n[16] INSTALANDO TAREFA AGENDADA (Logon) PARA GARANTIR PINS..." -ForegroundColor Cyan

    $helperScriptContent = @'
param()

function New-Shortcut([string]$Path,[string]$TargetPath){
  $ws=New-Object -ComObject WScript.Shell
  $sc=$ws.CreateShortcut($Path); $sc.TargetPath=$TargetPath; $sc.Save()
}
function Normalize-String([string]$s){ if(-not $s){return ""}; $n=$s.Normalize([Text.NormalizationForm]::FormD); return ([regex]::Replace($n,"\p{Mn}","")) }
function Pin-ToTaskbar([string]$TargetPath){
  # Remover pins existentes para evitar duplicatas
  $taskbarPinsPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
  if (Test-Path $taskbarPinsPath) {
      Get-ChildItem $taskbarPinsPath -Filter "*.lnk" -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -eq ([IO.Path]::GetFileNameWithoutExtension($TargetPath)) } | Remove-Item -Force -ErrorAction SilentlyContinue
  }

  try{
    $tmp=Join-Path $env:TEMP ("pin_"+[IO.Path]::GetFileNameWithoutExtension($TargetPath)+".lnk")
    New-Shortcut -Path $tmp -TargetPath $TargetPath
    $sh=New-Object -ComObject Shell.Application
    $f=$sh.Namespace((Split-Path $tmp)); $i=$f.ParseName((Split-Path $tmp -Leaf))
    if($i){ foreach($v in $i.Verbs()){ $n=Normalize-String($v.Name.ToString().ToLower()); if($n -match "pin to taskbar|barra de tarefas|taskleiste|barra de tareas|anheften|taskbar"){ try{$v.DoIt()}catch{} } } }
  } finally { Remove-Item $tmp -Force -ea SilentlyContinue }
}

function Pin-ToStartMenu([string]$TargetPath){
  try{
    $tmp=Join-Path $env:TEMP ("pin_start_"+[IO.Path]::GetFileNameWithoutExtension($TargetPath)+".lnk")
    New-Shortcut -Path $tmp -TargetPath $TargetPath
    $sh=New-Object -ComObject Shell.Application
    $f=$sh.Namespace((Split-Path $tmp)); $i=$f.ParseName((Split-Path $tmp -Leaf))
    if($i){ foreach($v in $i.Verbs()){ $n=Normalize-String($v.Name.ToString().ToLower()); if($n -match "pin to start|pinar no inicio|an start anheften"){ try{$v.DoIt()}catch{} } } }
  } finally { Remove-Item $tmp -Force -ea SilentlyContinue }
}

$itemsToPin = @(
    "$env:windir\System32\cmd.exe",
    "$env:windir\System32\notepad.exe",
    "$env:windir\explorer.exe"
)

Start-Sleep -Seconds 10 # Dar tempo para o ambiente carregar
foreach ($item in $itemsToPin) {
    Pin-ToTaskbar -TargetPath $item
    Pin-ToStartMenu -TargetPath $item
}

# remove Edge/Store lnk se reaparecerem
$taskbarPinsPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
if (Test-Path $taskbarPinsPath) {
    Get-ChildItem $taskbarPinsPath -Filter "*Edge*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem $taskbarPinsPath -Filter "*Store*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

# Remover Edge do Menu Iniciar

if (Test-Path $startMenuEdgePath) {
    Remove-Item $startMenuEdgePath -Force -ErrorAction SilentlyContinue
}

# Remover Edge do Menu Iniciar (para garantir)
if (Test-Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk") {
    Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
}
if (Test-Path $startMenuEdgePath) {
    Remove-Item $startMenuEdgePath -Force -ErrorAction SilentlyContinue
}
'@
    $helperPath = "C:\ProgramData\FixTaskbarPins.ps1"
    try {
        $helperScriptContent | Out-File -FilePath $helperPath -Encoding UTF8 -Force

        $action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$helperPath`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $principal = New-ScheduledTaskPrincipal -GroupId "Users" -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

        try {
            Unregister-ScheduledTask -TaskName "FixTaskbarPins" -Confirm:$false -ErrorAction SilentlyContinue
        } catch {}
        Register-ScheduledTask -TaskName "FixTaskbarPins" -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
        Write-Host "OK (tarefa 'FixTaskbarPins')." -ForegroundColor Green
    } catch { Write-Warning "Falha ao instalar tarefa agendada 'FixTaskbarPins': $($_.Exception.Message)" }
}

# =====================================================
# EXECUÇÃO PRINCIPAL
# =====================================================
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "ESTE SCRIPT DEVE SER EXECUTADO COMO ADMINISTRADOR!"
    return
}

Write-Host "`n[0] VALIDACOES INICIAIS..." -ForegroundColor Cyan

# 1) Básico do sistema
Set-TimeZoneToSaoPaulo
Remove-OneDrive
Remove-BloatwareApps
Apply-SystemPolicies
Disable-Telemetry
Disable-NewsAndInterests
Disable-Cortana
Disable-GameBar
Disable-SmartScreen
Disable-NotificationsAndTips
Disable-TaskViewButton

# 2) Start e Taskbar – criar material base e limpar
Clear-StartMenuPins

# 3) Tweaks e teclado
Set-KeyboardToBRABNT2

# 4) Forçar aplicação (reset cache + repin atual) e instalar agente de retomada
Pin-EssentialItems
Reset-Taskband-ForAllUsers
Install-LogonFixTaskbarScheduledTask

# 5) Reiniciar Explorer para refletir tudo
Restart-Explorer

Write-Host "`n===> LIMPEZA E CONFIGURACOES CONCLUIDAS!" -ForegroundColor Green
Start-Sleep -Seconds 2
# Restart-Computer   # descomentare se quiser forçar reboot





# Remover Barra de Pesquisa da Barra de Tarefas
function Disable-TaskbarSearch {
    Write-Host "`n[X] REMOVENDO BARRA DE PESQUISA DA BARRA DE TAREFAS..." -ForegroundColor Cyan
    try {
        Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -Type "DWord"
        Write-Host "OK." -ForegroundColor Green
    } catch { Write-Warning "Falha ao remover barra de pesquisa: $($_.Exception.Message)" }
}
Disable-TaskbarSearch
#Set-ExecutionPolicy Restricted
Start-Sleep -Seconds 5
#Restart-Computer

