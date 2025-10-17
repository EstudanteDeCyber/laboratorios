# EXECUTAR ESTE SCRIPT COMO ADMINISTRADOR
Set-ExecutionPolicy Bypass -Scope Process -Force

Write-Host "`n=== INSTALACAO / ATUALIZACAO DO FIREFOX E NOTEPAD++ ===`n"

# ========================
# FIREFOX
# ========================
Write-Host "[*] VERIFICANDO VERSAO DO FIREFOX INSTALADA..."

$firefoxExe = "C:\Program Files\Mozilla Firefox\firefox.exe"
$installedVersion = $null

if (Test-Path $firefoxExe) {
    $fileInfo = (Get-Item $firefoxExe).VersionInfo
    $installedVersion = $fileInfo.ProductVersion
    Write-Host "    - VERSAO INSTALADA: $installedVersion"
} else {
    Write-Host "    - FIREFOX NAO ENCONTRADO."
}

Write-Host "[*] OBTENDO VERSAO MAIS RECENTE DO FIREFOX..."
$firefoxVersionJson = Invoke-RestMethod -Uri "https://product-details.mozilla.org/1.0/firefox_versions.json"
$latestVersion = $firefoxVersionJson.LATEST_FIREFOX_VERSION
Write-Host "    - ULTIMA VERSAO DISPONIVEL: $latestVersion"

if ($installedVersion -and ($installedVersion -eq $latestVersion)) {
    Write-Host "[=] FIREFOX JA ESTA ATUALIZADO. NENHUMA ACAO NECESSARIA.`n"
} else {
    Write-Host "[*] BAIXANDO ULTIMA VERSAO DO FIREFOX..."
    $firefoxUrl = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=pt-BR"
    $firefoxInstaller = "$env:TEMP\firefox_installer.exe"

    Invoke-WebRequest -Uri $firefoxUrl -OutFile $firefoxInstaller -UseBasicParsing
    Write-Host "[*] INSTALANDO / ATUALIZANDO FIREFOX..."
    Start-Process -FilePath $firefoxInstaller -ArgumentList "/S" -Wait
    Remove-Item $firefoxInstaller -Force
    Write-Host "[+] FIREFOX ATUALIZADO COM SUCESSO PARA A VERSAO $latestVersion!`n"
}

# ========================
# NOTEPAD++
# ========================
Write-Host "[*] OBTENDO URL DA ULTIMA VERSAO DO NOTEPAD++ (VIA GITHUB API)..."

$releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest"
$nppUrl = $releaseInfo.assets.browser_download_url | Where-Object {$_ -match "Installer.x64.exe$"} | Select-Object -First 1

if (-not $nppUrl) {
    Write-Error "NAO FOI POSSIVEL ENCONTRAR O INSTALADOR DO NOTEPAD++ NO GITHUB."
    exit 1
}

Write-Host "[*] BAIXANDO INSTALADOR DO NOTEPAD++: $nppUrl"
$nppInstaller = "$env:TEMP\npp_installer.exe"
Invoke-WebRequest -Uri $nppUrl -OutFile $nppInstaller -UseBasicParsing

Write-Host "[*] INSTALANDO / ATUALIZANDO NOTEPAD++..."
Start-Process -FilePath $nppInstaller -ArgumentList "/S" -Wait
Remove-Item $nppInstaller -Force

Write-Host "[+] NOTEPAD++ ATUALIZADO COM SUCESSO!`n"
Write-Host "=== PROCESSO CONCLUIDO! AMBOS ESTAO NA ULTIMA VERSAO ==="
