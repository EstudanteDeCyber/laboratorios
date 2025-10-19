# Configurar encoding UTF-8 para evitar caracteres corrompidos
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

param(
    [switch]$Force  # Continua em erros não fatais
)

# Script PowerShell para Validar o Setup do Lab DLL Hijacking (Versão 1.0)
# Autor: Grok | Data: Setembro 2025
# Objetivo: Verificar se o ambiente do laboratório (configurado por setup.ps1) está correto
# Executar como Administrador na VM Windows 11
# Requisitos: setup.ps1 já executado, PowerShell 5+

Write-Host "=== Iniciando Validação do Laboratório DLL Hijacking (Versão 1.0) ===" -ForegroundColor Green
Write-Host "Dica: Este script verifica pastas, ferramentas, aplicativos e artefatos. Rode como admin." -ForegroundColor Yellow

# Função para Verificar Privilégios de Admin
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "OK: Executando como Administrador." -ForegroundColor Green
        return $true
    } else {
        Write-Host "ERRO: Execute como Administrador!" -ForegroundColor Red
        exit 1
    }
}

# Função para Verificar Existência de Arquivo/Diretório
function Test-PathExists {
    param([string]$Path, [string]$Description)
    if (Test-Path $Path) {
        Write-Host "OK: $Description encontrado em $Path" -ForegroundColor Green
        return $true
    } else {
        Write-Host "ERRO: $Description NÃO encontrado em $Path" -ForegroundColor Red
        if ($Force) { Write-Host "Continuando com -Force..." -ForegroundColor Yellow; return $false }
        else { exit 1 }
    }
}

# Função para Testar Comando
function Test-Command {
    param([string]$Cmd, [string]$ExpectedOutput, [string]$Description)
    try {
        $output = Invoke-Expression $Cmd 2>&1
        if ($output -match $ExpectedOutput) {
            Write-Host "OK: $Description ($Cmd)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "ERRO: $Description falhou. Output: $output" -ForegroundColor Red
            if ($Force) { return $false } else { exit 1 }
        }
    } catch {
        Write-Host "ERRO: $Description falhou: $($_.Exception.Message)" -ForegroundColor Red
        if ($Force) { return $false } else { exit 1 }
    }
}

# Função para Testar Velociraptor GUI
function Test-VelociraptorGUI {
    param([string]$ExePath, [string]$ConfigPath)
    Write-Host "Testando Velociraptor GUI..." -ForegroundColor Cyan
    try {
        $guiTest = Start-Process -FilePath $ExePath -ArgumentList "gui --config $ConfigPath --frontend-bind-address 127.0.0.1:8000" -PassThru
        Start-Sleep 5
        if ($guiTest.HasExited) {
            Write-Host "ERRO: Velociraptor GUI não iniciou (porta 8000 ocupada?)." -ForegroundColor Red
            return $false
        } else {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:8000" -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Write-Host "OK: Velociraptor GUI acessível em http://127.0.0.1:8000" -ForegroundColor Green
                Stop-Process -Id $guiTest.Id -Force
                return $true
            } else {
                Write-Host "ERRO: Velociraptor GUI não respondeu (status: $($response.StatusCode))." -ForegroundColor Red
                Stop-Process -Id $guiTest.Id -Force
                return $false
            }
        }
    } catch {
        Write-Host "ERRO: Velociraptor GUI falhou: $($_.Exception.Message)" -ForegroundColor Red
        Stop-Process -Id $guiTest.Id -Force -ErrorAction SilentlyContinue
        return $false
    }
}

# Início da Validação
Write-Host "`nVerificando privilégios..." -ForegroundColor Cyan
Test-Admin

# Adicionar C:\mingw32\bin ao PATH para que o PowerShell encontre gcc e g++
$env:Path = "C:\mingw32\bin;" + $env:Path
Write-Host "PATH atualizado para incluir C:\mingw32\bin" -ForegroundColor DarkGreen

# 1. Validar Estrutura de Pastas
Write-Host "`n1. Validando Estrutura de Pastas..." -ForegroundColor Green
$folders = @(
    @{Path="C:\Lab"; Description="Pasta raiz do laboratório"},
    @{Path="C:\Lab\DLLHijack"; Description="Pasta DLLHijack"},
    @{Path="C:\Lab\DLLHijack\Apps"; Description="Pasta de aplicativos"},
    @{Path="C:\Lab\DLLHijack\DLLs"; Description="Pasta de DLLs"},
    @{Path="C:\Lab\DLLHijack\Tools"; Description="Pasta de ferramentas"},
    @{Path="C:\ProgramData\TestApp"; Description="Pasta TestApp"}
)
$folderErrors = 0
foreach ($folder in $folders) {
    if (-not (Test-PathExists -Path $folder.Path -Description $folder.Description)) {
        $folderErrors++
    }
}

# 2. Validar Ferramentas
Write-Host "`n2. Validando Ferramentas..." -ForegroundColor Green
$tools = @(
    @{Path="C:\Lab\DLLHijack\Tools\ProcMon\Procmon64.exe"; Description="Process Monitor (ProcMon)"},
    @{Path="C:\Lab\DLLHijack\Tools\Dependencies\DependenciesGui.exe"; Description="Dependencies"},
    @{Path="C:\mingw32\bin\gcc.exe"; Description="MinGW-w64 GCC"},
    @{Path="C:\Program Files\Python312\python.exe"; Description="Python 3.12"},
    @{Path="C:\Lab\DLLHijack\Tools\velociraptor.exe"; Description="Velociraptor"}
)
$toolErrors = 0
foreach ($tool in $tools) {
    if (-not (Test-PathExists -Path $tool.Path -Description $tool.Description)) {
        $toolErrors++
    }
}

# 3. Validar Funcionalidade das Ferramentas
Write-Host "`n3. Validando Funcionalidade das Ferramentas..." -ForegroundColor Green
$commandTests = @(
    @{Cmd="gcc --version"; ExpectedOutput="15.2.0"; Description="GCC (MinGW-w64)"},
    @{Cmd="g++ --version"; ExpectedOutput="15.2.0"; Description="G++ (MinGW-w64)"},
    @{Cmd="python --version"; ExpectedOutput="3.12"; Description="Python 3.12"},
    @{Cmd="pip show pefile"; ExpectedOutput="pefile"; Description="Python pefile module"}
)
$commandErrors = 0
foreach ($test in $commandTests) {
    if (-not (Test-Command -Cmd $test.Cmd -ExpectedOutput $test.ExpectedOutput -Description $test.Description)) {
        $commandErrors++
    }
}

# 4. Validar Velociraptor GUI
Write-Host "`n4. Validando Velociraptor GUI..." -ForegroundColor Green
$veloErrors = 0
if (Test-Path "C:\Lab\DLLHijack\Tools\velociraptor.exe") {
    if (-not (Test-VelociraptorGUI -ExePath "C:\Lab\DLLHijack\Tools\velociraptor.exe" -ConfigPath "C:\Lab\DLLHijack\Tools\config.yaml")) {
        $veloErrors++
        Write-Host "Dica: Verifique porta 8000 ou edite config.yaml para 8001." -ForegroundColor Yellow
    }
} else {
    Write-Host "ERRO: Velociraptor não encontrado." -ForegroundColor Red
    $veloErrors++
}

# 5. Validar Artefatos Compilados
Write-Host "`n5. Validando Artefatos Compilados..." -ForegroundColor Green
$artifacts = @(
    @{Path="C:\Lab\DLLHijack\Apps\testapp.exe"; Description="Aplicativo testapp.exe"},
    @{Path="C:\Lab\DLLHijack\DLLs\test.dll"; Description="DLL legítima test.dll"},
    @{Path="C:\Lab\DLLHijack\DLLs\mal.dll"; Description="DLL maliciosa mal.dll"}
)
$artifactErrors = 0
foreach ($artifact in $artifacts) {
    if (-not (Test-PathExists -Path $artifact.Path -Description $artifact.Description)) {
        $artifactErrors++
    }
}

# 6. Validar KeePassXC (incluindo download e extracao se necessario)
Write-Host "`n6. Validando KeePassXC..." -ForegroundColor Green
$keepassErrors = 0
$keepassExePath = "C:\Lab\DLLHijack\Apps\KeePassXC\KeePassXC.exe"

if (-not (Test-Path $keepassExePath)) {
    Write-Host "KeePassXC nao encontrado. Tentando baixar e extrair..." -ForegroundColor Yellow
    if (-not (Download-AndExtract-KeePassXC)) {
        $keepassErrors++
        Write-Host "ERRO: Falha ao baixar ou extrair KeePassXC." -ForegroundColor Red
    }
} else {
    Write-Host "OK: KeePassXC encontrado em $keepassExePath" -ForegroundColor Green
}


# Resumo
Write-Host "`n=== Resumo da Validação ===" -ForegroundColor Green
$totalErrors = $folderErrors + $toolErrors + $commandErrors + $veloErrors + $artifactErrors + $keepassErrors
if ($totalErrors -eq 0) {
    Write-Host "SUCESSO: Todas as validações passaram! O ambiente está pronto para o laboratório." -ForegroundColor Green
} else {
    Write-Host "ERRO: $totalErrors falhas detectadas." -ForegroundColor Red
    Write-Host "Pastas: $folderErrors erros" -ForegroundColor Yellow
    Write-Host "Ferramentas: $toolErrors erros" -ForegroundColor Yellow
    Write-Host "Comandos: $commandErrors erros" -ForegroundColor Yellow
    Write-Host "Velociraptor: $veloErrors erros" -ForegroundColor Yellow
    Write-Host "Artefatos: $artifactErrors erros" -ForegroundColor Yellow
    Write-Host "KeePassXC: $keepassErrors erros" -ForegroundColor Yellow
    if ($Force) {
        Write-Host "Continuando com -Force, mas corrija os erros antes do laboratório." -ForegroundColor Yellow
    } else {
        Write-Host "Corrija os erros e reexecute o setup.ps1." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Validação concluída. Verifique os logs acima para detalhes." -ForegroundColor Cyan