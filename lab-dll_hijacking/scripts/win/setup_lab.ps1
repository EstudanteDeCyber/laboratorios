# =================================================================================
# Script PowerShell para Automatizar Passo 3 do Lab DLL Hijacking (Versao 2.0)
#
# !!! COMO EXECUTAR !!!
# 1. Salve este arquivo como 'setup.ps1' na pasta 'C:\tmp'.
# 2. Abra o PowerShell COMO ADMINISTRADOR.
# 3. Navegue ate a pasta correta e execute o script com os comandos:
#
#    cd C:\tmp
#    .\setup.ps1
#
# Autor: Grok & Manus | Data: Setembro 2025
# Mudancas: Corrigido erro de 'multiple definition' na compilacao do g++
#           usando a flag '-static' para linkagem estatica limpa.
# =================================================================================

param(
    [switch]$Force
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== Iniciando Automacao do Passo 3: Ferramentas e Apps (Versao 2.0) ===" -ForegroundColor Green
Write-Host "Dica: O script agora compila todos os artefatos necessarios (testapp, test.dll, mal.dll)." -ForegroundColor Yellow

# --- Funcoes Auxiliares ---

function Test-Admin {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "OK: Executando como Administrador." -ForegroundColor Green; return $true
    } else {
        Write-Host "ERRO: Este script precisa ser executado como Administrador!" -ForegroundColor Red
        if (-not $Force) { exit 1 }
    }
}

function New-LabFolder {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null; Write-Host "Pasta criada: $Path"
    } else {
        Write-Host "Pasta ja existe: $Path" -ForegroundColor Yellow
    }
}

function Download-File {
    param([string]$Url, [string]$OutputPath, [int]$MaxRetries = 3)
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-Host "Baixando (tentativa $i/$MaxRetries): $Url..." -ForegroundColor Cyan
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -ErrorAction Stop
            $sizeMB = [math]::Round((Get-Item $OutputPath).Length / 1MB, 2)
            Write-Host "Download concluido: $sizeMB MB" -ForegroundColor Green
            return
        } catch {
            Write-Host "ERRO no download (tentativa $i): $($_.Exception.Message)" -ForegroundColor Red
            if ($i -lt $MaxRetries) { Start-Sleep 5 } else { if ($Force) { return } else { exit 1 } }
        }
    }
}

function Extract-File {
    param([string]$ArchivePath, [string]$DestPath)
    $7zPath = "C:\Program Files\7-Zip\7z.exe"
    if (-not (Test-Path $7zPath)) {
        Write-Host "7-Zip nao encontrado. Instalando automaticamente..." -ForegroundColor Yellow
        Download-File -Url "https://www.7-zip.org/a/7z2408-x64.exe" -OutputPath "$env:TEMP\7z-install.exe"
        Start-Process -FilePath "$env:TEMP\7z-install.exe" -ArgumentList "/S" -Wait
        Remove-Item "$env:TEMP\7z-install.exe" -Force
    }
    try {
        Write-Host "Extraindo: $ArchivePath para $DestPath..." -ForegroundColor Cyan
        & $7zPath x $ArchivePath -o"$DestPath" -y | Out-Null
        Write-Host "Extracao concluida com sucesso." -ForegroundColor Green
    } catch {
        Write-Host "ERRO na extracao: $($_.Exception.Message )." -ForegroundColor Red
        if ($Force) { Write-Host "Continuando..." } else { exit 1 }
    }
}

function Test-Command-Exists {
    param([string]$Command)
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Write-Host "Comando '$Command' encontrado no PATH." -ForegroundColor Green; return $true
    } else {
        Write-Host "ERRO: Comando '$Command' NAO encontrado no PATH." -ForegroundColor Red; return $false
    }
}

# --- INICIO DA EXECUCAO DO SCRIPT ---

Write-Host "`nVerificando privilegios..." -ForegroundColor Cyan
Test-Admin

Write-Host "`n1. Criando Estrutura de Pastas..." -ForegroundColor Green
New-LabFolder "C:\Lab"; New-LabFolder "C:\Lab\DLLHijack"; New-LabFolder "C:\Lab\DLLHijack\Apps"; New-LabFolder "C:\Lab\DLLHijack\DLLs"; New-LabFolder "C:\Lab\DLLHijack\Tools"; New-LabFolder "C:\ProgramData\TestApp"

Write-Host "`n2. Instalando Ferramentas (ProcMon, Dependencies)..." -ForegroundColor Green
Download-File -Url "https://live.sysinternals.com/Procmon.exe" -OutputPath "C:\Lab\Procmon.exe"
New-LabFolder "C:\Lab\DLLHijack\Tools\ProcMon"
Copy-Item "C:\Lab\Procmon.exe" "C:\Lab\DLLHijack\Tools\ProcMon\Procmon64.exe" -Force
Remove-Item "C:\Lab\Procmon.exe" -Force -ErrorAction SilentlyContinue
Download-File -Url "https://github.com/lucasg/Dependencies/releases/download/v1.11.1/Dependencies_x64_Release.zip" -OutputPath "C:\Lab\Dependencies.zip"
Extract-File -ArchivePath "C:\Lab\Dependencies.zip" -DestPath "C:\Lab\DLLHijack\Tools\Dependencies"
Remove-Item "C:\Lab\Dependencies.zip" -Force -ErrorAction SilentlyContinue
Write-Host "Ferramentas basicas instaladas."

Write-Host "`n3. Instalando MinGW-w64 e Corrigindo PATH..." -ForegroundColor Green
Download-File -Url "https://github.com/brechtsanders/winlibs_mingw/releases/download/15.2.0posix-13.0.0-msvcrt-r1/winlibs-i686-posix-dwarf-gcc-15.2.0-mingw-w64msvcrt-13.0.0-r1.zip" -OutputPath "C:\Lab\mingw.zip"
Extract-File -ArchivePath "C:\Lab\mingw.zip" -DestPath "C:\"
Remove-Item "C:\Lab\mingw.zip" -Force -ErrorAction SilentlyContinue
$mingwPath = "C:\mingw32\bin"
$env:Path = $mingwPath + ";" + $env:Path
Write-Host "PATH da sessao atual atualizado para incluir $mingwPath." -ForegroundColor Green
Test-Command-Exists "gcc"
Test-Command-Exists "g++"

Write-Host "`n4. Compilando Artefatos do Laboratorio..." -ForegroundColor Green

# Compilar testapp.exe (C++ )
Set-Location "C:\Lab\DLLHijack\Apps"
if (Get-Command g++ -ErrorAction SilentlyContinue) {
    Write-Host "Compilando testapp.exe..." -ForegroundColor Cyan
    $testappCode = '#include <windows.h>
#include <iostream>
int main() {
    std::cout << "App rodando. Carregando DLL..." << std::endl;
    HMODULE dll = LoadLibraryA("test.dll");
    if (dll == NULL) {
        std::cout << "Erro: test.dll nao encontrado!" << std::endl;
    } else {
        std::cout << "DLL carregada com sucesso." << std::endl;
    }
    system("pause");
    return 0;
}'
    $testappCode | Out-File -FilePath "testapp.cpp" -Encoding utf8
    
    # Correcao: Usar a flag -static para evitar conflitos de linkagem
    g++ testapp.cpp -o testapp.exe -static
    
    if (Test-Path "testapp.exe") {
        Write-Host "SUCESSO: 'testapp.exe' compilado em C:\Lab\DLLHijack\Apps" -ForegroundColor Green
        Remove-Item "testapp.cpp" -Force
    } else {
        Write-Host "ERRO: Falha ao compilar testapp.exe" -ForegroundColor Red
    }
}

# Compilar DLLs (C)
Set-Location "C:\Lab\DLLHijack\DLLs"
if (Get-Command gcc -ErrorAction SilentlyContinue) {
    # Compilar test.dll (legitima)
    Write-Host "Compilando test.dll (legitima)..." -ForegroundColor Cyan
    $legitDllCode = '#include <windows.h>
BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    if (ul_reason_for_call == DLL_PROCESS_ATTACH) {
        MessageBoxA(NULL, "test.dll legitima carregada!", "Legit DLL", MB_OK);
    }
    return TRUE;
}'
    $legitDllCode | Out-File -FilePath "test.c" -Encoding utf8
    gcc test.c -shared -o test.dll
    if (Test-Path "test.dll") {
        Write-Host "SUCESSO: 'test.dll' compilada em C:\Lab\DLLHijack\DLLs" -ForegroundColor Green
        Remove-Item "test.c" -Force
    } else {
        Write-Host "ERRO: Falha ao compilar test.dll" -ForegroundColor Red
    }

    # Compilar mal.dll (maliciosa)
    Write-Host "Compilando mal.dll (simulacao)..." -ForegroundColor Cyan
    $malDllCode = '#include <windows.h>
BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    if (ul_reason_for_call == DLL_PROCESS_ATTACH) {
        MessageBoxA(NULL, "DLL Hijack Simulado - Educacional!", "Lab Alert", MB_OK | MB_ICONINFORMATION);
    }
    return TRUE;
}'
    $malDllCode | Out-File -FilePath "mal.c" -Encoding utf8
    gcc mal.c -shared -o mal.dll
    if (Test-Path "mal.dll") {
        Write-Host "SUCESSO: 'mal.dll' compilada em C:\Lab\DLLHijack\DLLs" -ForegroundColor Green
        Remove-Item "mal.c" -Force
    } else {
        Write-Host "ERRO: Falha ao compilar mal.dll" -ForegroundColor Red
    }
}

Write-Host "`n5. Instalando Ferramentas Adicionais (Python, Velociraptor)..." -ForegroundColor Green
# Python
Download-File -Url "https://www.python.org/ftp/python/3.12.6/python-3.12.6-amd64.exe" -OutputPath "C:\Lab\python-installer.exe"
Start-Process -FilePath "C:\Lab\python-installer.exe" -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait
Remove-Item "C:\Lab\python-installer.exe" -Force
$env:Path = "C:\Program Files\Python312\Scripts\;C:\Program Files\Python312\;" + $env:Path
if (Test-Command-Exists "python" ) {
    python -m pip install --upgrade pip; python -m pip install pefile
}

# Velociraptor
$veloUrl = (Invoke-RestMethod -Uri "https://api.github.com/repos/Velocidex/velociraptor/releases/latest" ).assets | Where-Object { $_.name -like "*windows-amd64.exe" } | Select-Object -ExpandProperty browser_download_url -First 1
Download-File -Url $veloUrl -OutputPath "C:\Lab\DLLHijack\Tools\velociraptor.exe"
Set-Location "C:\Lab\DLLHijack\Tools"
.\velociraptor.exe config generate --os windows > config.yaml
Write-Host "Velociraptor instalado e configurado (nao-interativo)."

Write-Host "`n=== Automacao do Laboratorio Concluida! ===" -ForegroundColor Green
Write-Host "Resumo: Todas as ferramentas estao instaladas e os 3 artefatos (testapp.exe, test.dll, mal.dll) foram compilados." -ForegroundColor Cyan
Write-Host "Seu ambiente de laboratorio esta pronto para iniciar os testes de DLL Hijacking." -ForegroundColor Yellow
Set-Location C:\tmp