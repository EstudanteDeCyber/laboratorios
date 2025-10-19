# Executar como administrador

Write-Host "Iniciando ajustes no Windows 11..." -ForegroundColor Cyan

# ---------------------------------------------
# 1. Remover o OneDrive completamente
# ---------------------------------------------

Write-Host "Removendo o OneDrive..." -ForegroundColor Yellow

# Finalizar qualquer processo do OneDrive
taskkill /f /im OneDrive.exe 2>$null

# Desinstalar OneDrive (versão Win32)
$onedriveSetupPath = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
if (Test-Path $onedriveSetupPath) {
    & $onedriveSetupPath /uninstall
} else {
    $onedriveSetupPath = "$env:SYSTEMROOT\System32\OneDriveSetup.exe"
    if (Test-Path $onedriveSetupPath) {
        & $onedriveSetupPath /uninstall
    }
}

# Remover app da Microsoft Store (versão UWP)
Get-AppxPackage *OneDrive* | Remove-AppxPackage -ErrorAction SilentlyContinue

# Remover diretórios residuais
Remove-Item "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:PROGRAMDATA\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue

# Limpar tarefas agendadas relacionadas ao OneDrive
Get-ScheduledTask | Where-Object { $_.TaskName -like "*OneDrive*" } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "OneDrive removido com sucesso." -ForegroundColor Green

# ---------------------------------------------
# 2. Desativar os Widgets (lado esquerdo da barra)
# ---------------------------------------------

Write-Host "Desativando os Widgets..." -ForegroundColor Yellow

# O valor 0 desativa os widgets
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -PropertyType DWORD -Force

# Também desativa via política (GPO Local)
New-Item -Path "HKLM:\Software\Policies\Microsoft\Dsh" -Force | Out-Null
New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -PropertyType DWord -Value 0 -Force

Write-Host "Widgets desativados." -ForegroundColor Green

# ---------------------------------------------
# 3. Ajustar menu iniciar para o lado esquerdo
# ---------------------------------------------

Write-Host "Ajustando o menu iniciar para a esquerda..." -ForegroundColor Yellow

# Alinhar menu iniciar à esquerda
# Valor 0 = Esquerda | Valor 1 = Centro
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0 -PropertyType DWORD -Force

Write-Host "Menu iniciar ajustado para o lado esquerdo." -ForegroundColor Green

# ---------------------------------------------
# Finalização
# ---------------------------------------------
Write-Host "`nTodas as alterações foram aplicadas." -ForegroundColor Cyan
Write-Host "Você pode precisar reiniciar o computador para que tudo tenha efeito." -ForegroundColor Magenta