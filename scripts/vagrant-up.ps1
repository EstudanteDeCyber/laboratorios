param (
    [string]$VagrantArgs = "up" # Comando padrão é "vagrant up"
)

# Função: Define o Vagrantfile baseado no padrão Vagrantfile_*
function Set-VagrantfileEnv {
    $Vagrantfile = Get-ChildItem -Path . -Filter "Vagrantfile_*" | Select-Object -First 1
    if ($null -eq $Vagrantfile) {
        Write-Host "❌ Nenhum Vagrantfile_* encontrado no diretório atual." -ForegroundColor Red
        exit 1
    }
    $env:VAGRANT_VAGRANTFILE = $Vagrantfile.Name
    Write-Host "✅ VAGRANT_VAGRANTFILE definido como: $($env:VAGRANT_VAGRANTFILE)"
}

# Função: Executa o script pos_install_<SUFIXO>.ps1 baseado no Vagrantfile
function Run-PostInstallScript {
    if (-not $env:VAGRANT_VAGRANTFILE) {
        Write-Host "❌ VAGRANT_VAGRANTFILE não está definido." -ForegroundColor Red
        exit 1
    }

    if ($env:VAGRANT_VAGRANTFILE -match "^Vagrantfile_(.+)$") {
        $Suffix = $Matches[1]
        $ScriptName = "pos_install_${Suffix}.ps1"
        $ScriptPath = Join-Path -Path $ProjectPath -ChildPath "scripts\$ScriptName"

        Write-Host "Executando $ScriptName..."

        if (-not (Test-Path $ScriptPath)) {
            Write-Host "❌ Script $ScriptName não encontrado em $ScriptPath." -ForegroundColor Red
            exit 1
        }

        powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Erro ao executar $ScriptName." -ForegroundColor Red
            exit $LASTEXITCODE
        }

        Write-Host "✅ $ScriptName executado com sucesso." -ForegroundColor Green
    } else {
        Write-Host "❌ Nome do Vagrantfile não segue o padrão esperado." -ForegroundColor Red
        exit 1
    }
}

# Pega a pasta atual onde o comando está sendo executado
$ProjectPath = (Get-Location).Path

# ⚙️ Define o Vagrantfile automaticamente
Set-VagrantfileEnv

# Garante que o Vagrant use o catálogo GLOBAL de boxes
$env:VAGRANT_HOME = "D:\VMs\VirtualBox\Boxes"

# Salva o machinefolder atual do VirtualBox (apenas para exibição)
$OriginalMachineFolder = (& VBoxManage list systemproperties | Select-String "Default machine folder").ToString().Split(":", 2)[1].Trim()
Write-Host "Machine folder atual: $OriginalMachineFolder"
Write-Host "Definindo machinefolder temporário para: $ProjectPath"

# Seta o machinefolder para a pasta atual
VBoxManage setproperty machinefolder "$ProjectPath"

# Vai até a pasta atual
Push-Location $ProjectPath

# Prepara os argumentos como array (split por espaço)
$ArgList = $VagrantArgs.Split(" ")

# Executa o vagrant com os argumentos recebidos
Write-Host "Rodando: vagrant $VagrantArgs"
& vagrant @ArgList

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erro ao executar 'vagrant $VagrantArgs'. Verifique os logs para detalhes."
    Pop-Location
    # Define o machinefolder para D:\VMs\VirtualBox em caso de erro
    Write-Host "Restaurando machinefolder para: D:\VMs\VirtualBox"
    VBoxManage setproperty machinefolder "D:\VMs\VirtualBox"
    exit $LASTEXITCODE
}

# 🔁 Executa o pos_install correto se comando for "up" ou vazio
if ($VagrantArgs -eq "up" -or $VagrantArgs -eq "") {
    Run-PostInstallScript
} else {
    Write-Host "ℹ️ Pulando execução de pos_install.ps1, pois o comando não é 'up'."
}

# Volta para a pasta original
Pop-Location

# Define o machinefolder para D:\VMs\VirtualBox
Write-Host "Restaurando machinefolder para: D:\VMs\VirtualBox"
VBoxManage setproperty machinefolder "D:\VMs\VirtualBox"