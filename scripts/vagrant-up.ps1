param (
    [string]$VagrantArgs = "up" # COMANDO PADRAO É "VAGRANT UP"
)

# ⚙️ FUNCAO: DEFINE O VAGRANTFILE BASEADO NO PADRÃO Vagrantfile_*
function Set-VagrantfileEnv {
    $Vagrantfile = Get-ChildItem -Path . -Filter "Vagrantfile_*" | Select-Object -First 1
    if ($null -eq $Vagrantfile) {
        Write-Host "❌ NENHUM VAGRANTFILE_* ENCONTRADO NO DIRETÓRIO ATUAL." -ForegroundColor Red
        exit 1
    }
    $env:VAGRANT_VAGRANTFILE = $Vagrantfile.Name
    Write-Host "✅ VAGRANT_VAGRANTFILE DEFINIDO COMO: $($env:VAGRANT_VAGRANTFILE)"
}

# ⚙️ FUNÇÃO: EXECUTA O SCRIPT pos_install_<SUFIXO>.ps1 BASEADO NO VAGRANTFILE
function Run-PostInstallScript {
    if (-not $env:VAGRANT_VAGRANTFILE) {
        Write-Host "❌ VAGRANT_VAGRANTFILE NÃO ESTÁ DEFINIDO." -ForegroundColor Red
        exit 1
    }

    if ($env:VAGRANT_VAGRANTFILE -match "^Vagrantfile_(.+)$") {
        $Suffix = $Matches[1]
        $ScriptName = "pos_install_${Suffix}.ps1"
        $ScriptPath = Join-Path -Path $RootScriptsPath -ChildPath $ScriptName

        Write-Host "EXECUTANDO $ScriptName..."

        if (-not (Test-Path $ScriptPath)) {
            Write-Host "❌ SCRIPT $ScriptName NÃO ENCONTRADO EM $ScriptPath." -ForegroundColor Red
            exit 1
        }

        powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ ERRO AO EXECUTAR $ScriptName." -ForegroundColor Red
            exit $LASTEXITCODE
        }

        Write-Host "✅ $ScriptName EXECUTADO COM SUCESSO." -ForegroundColor Green
    } else {
        Write-Host "❌ NOME DO VAGRANTFILE NÃO SEGUE O PADRÃO ESPERADO." -ForegroundColor Red
        exit 1
    }
}

# 📂 OBTÉM A PASTA ATUAL DO PROJETO
$ProjectPath = (Get-Location).Path

# 📂 DEFINE O CAMINHO DA PASTA SCRIPTS (UM NÍVEL ACIMA DO PROJETO)
$RootScriptsPath = Join-Path -Path (Split-Path $ProjectPath -Parent) -ChildPath "scripts"

# ✅ VALIDA A EXISTÊNCIA DA PASTA DE SCRIPTS
if (-not (Test-Path $RootScriptsPath)) {
    Write-Host "❌ DIRETÓRIO DE SCRIPTS NÃO ENCONTRADO: $RootScriptsPath" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ Usando scripts em: $RootScriptsPath"
}

# ⚙️ DEFINE O VAGRANTFILE AUTOMATICAMENTE
Set-VagrantfileEnv

# 🗃️ DEFINE DIRETÓRIO PADRÃO DE BOXES DO VAGRANT
$env:VAGRANT_HOME = "D:\VMs\VirtualBox\Boxes"

# 💾 SALVA O MACHINEFOLDER ATUAL DO VIRTUALBOX (SÓ EXIBE)
$OriginalMachineFolder = (& VBoxManage list systemproperties | Select-String "Default machine folder").ToString().Split(":", 2)[1].Trim()
Write-Host "MACHINE FOLDER ATUAL: $OriginalMachineFolder"
Write-Host "DEFININDO MACHINEFOLDER TEMPORÁRIO PARA: $ProjectPath"

# 🔁 SETA O MACHINEFOLDER PARA A PASTA DO PROJETO
VBoxManage setproperty machinefolder "$ProjectPath"

# VAI PARA A PASTA DO PROJETO
Push-Location $ProjectPath

# EXECUTA O COMANDO VAGRANT COM OS ARGUMENTOS FORNECIDOS
$ArgList = $VagrantArgs.Split(" ")
Write-Host "RODANDO: vagrant $VagrantArgs"
& vagrant @ArgList

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ERRO AO EXECUTAR 'vagrant $VagrantArgs'. VERIFIQUE OS LOGS PARA DETALHES."
    Pop-Location
    Write-Host "RESTAURANDO MACHINEFOLDER PARA: D:\VMs\VirtualBox"
    VBoxManage setproperty machinefolder "D:\VMs\VirtualBox"
    exit $LASTEXITCODE
}

# 🚀 EXECUTA SCRIPT DE POS-INSTALAÇÃO APENAS SE O COMANDO FOR "UP"
if ($VagrantArgs -eq "up" -or $VagrantArgs -eq "") {
    Run-PostInstallScript
} else {
    Write-Host "ℹ️ PULANDO EXECUÇÃO DE pos_install.ps1, POIS O COMANDO NÃO É 'UP'."
}

# VOLTA PARA O LOCAL ORIGINAL
Pop-Location

# 🔄 RESTAURA O MACHINEFOLDER PADRÃO DO VIRTUALBOX
Write-Host "RESTAURANDO MACHINEFOLDER PARA: D:\VMs\VirtualBox"
VBoxManage setproperty machinefolder "D:\VMs\VirtualBox"
