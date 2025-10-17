param (
    [string]$VagrantArgs = "up"  # comando padrão é "vagrant up"
)

# Pega a pasta onde o script está salvo (junto do Vagrantfile)
$ProjectPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Garante que o Vagrant use o catálogo GLOBAL de boxes
$env:VAGRANT_HOME = "D:\VMs\VirtualBox\Boxes"

# Salva o machinefolder atual do VirtualBox
$OriginalMachineFolder = (& VBoxManage list systemproperties | Select-String "Default machine folder").ToString().Split(":",2)[1].Trim()

Write-Host "Machine folder atual: $OriginalMachineFolder"
Write-Host "Definindo machinefolder temporário para: $ProjectPath"

# Seta o machinefolder para a pasta do projeto
VBoxManage setproperty machinefolder "$ProjectPath"

# Vai até a pasta do projeto antes de rodar o vagrant
Push-Location $ProjectPath

# Prepara os argumentos como array (split por espaço)
$ArgList = $VagrantArgs.Split(" ")

# Executa o vagrant com os argumentos recebidos
Write-Host "Rodando: vagrant $VagrantArgs"
& vagrant @ArgList
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erro ao executar 'vagrant $VagrantArgs'. Verifique os logs para detalhes."
    Pop-Location
    VBoxManage setproperty machinefolder "$OriginalMachineFolder"
    exit $LASTEXITCODE
}

# Executa pos_install.ps1 somente se $VagrantArgs for "up" ou vazio (padrão "up")
if ($VagrantArgs -eq "up" -or $VagrantArgs -eq "") {
    $PosInstallScript = Join-Path $ProjectPath "pos_install.ps1"
    Write-Host "Executando pos_install.ps1..."
    if (-not (Test-Path $PosInstallScript)) {
        Write-Host "❌ Script pos_install.ps1 não encontrado em $PosInstallScript."
        Pop-Location
        VBoxManage setproperty machinefolder "$OriginalMachineFolder"
        exit 1
    }
    powershell -NoProfile -ExecutionPolicy Bypass -File $PosInstallScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erro ao executar pos_install.ps1."
        Pop-Location
        VBoxManage setproperty machinefolder "$OriginalMachineFolder"
        exit $LASTEXITCODE
    }
    Write-Host "✅ pos_install.ps1 executado com sucesso."
} else {
    Write-Host "ℹ️ Pulando execução de pos_install.ps1, pois o comando não é 'up'."
}

# Volta para a pasta original
Pop-Location

# Restaura o machinefolder original
Write-Host "Restaurando machinefolder para: $OriginalMachineFolder"
VBoxManage setproperty machinefolder "$OriginalMachineFolder"