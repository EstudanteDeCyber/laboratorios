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

# Volta para a pasta original
Pop-Location

# Restaura o machinefolder original
Write-Host "Restaurando machinefolder para: $OriginalMachineFolder"
VBoxManage setproperty machinefolder "$OriginalMachineFolder"
