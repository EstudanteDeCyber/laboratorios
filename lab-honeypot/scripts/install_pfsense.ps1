<#
.SYNOPSIS
    Script para criar uma VM pfSense no VirtualBox, descompactando a ISO, criando disco e configurando redes.

.DESCRIPTION
    Este script descompacta uma ISO compactada (.iso.gz), renomeia para um nome fixo, cria a VM com 4 interfaces de rede,
    desabilita áudio e USB, cria um disco virtual de 20 GB, anexa a ISO e o disco à VM, e configura NAT port forwarding.

.PARAMETER IsoGzPath
    Caminho completo para o arquivo .iso.gz do pfSense. Padrão: na pasta acima do script.

.PARAMETER VmName
    Nome da máquina virtual a ser criada. Padrão: "pfSense"

.PARAMETER CpuCount
    Número de CPUs virtuais. Padrão: 1

.PARAMETER MemoryMB
    Memória RAM em MB. Padrão: 2048

.PARAMETER WanNetName
    Nome da interface host-only ou NAT para WAN. Padrão: "nat"

.PARAMETER DmzIntName
    Nome da rede interna para DMZ. Padrão: "intnetDMZ"

.PARAMETER LanIntName
    Nome da rede interna para LAN. Padrão: "intnetLAN"

.PARAMETER ExtraHostOnlyNet
    Nome da interface host-only para a NIC4. Padrão: "VirtualBox Host-Only Ethernet Adapter"

.PARAMETER BasePath
    Caminho base onde a ISO será descompactada. Padrão: pasta acima do script.

.PARAMETER MyVmFolder
    Caminho onde a VM será criada. Padrão: pasta acima do script.

.EXAMPLE
    .\install_pfsense.ps1 -IsoGzPath "D:\VMs\LAB\netgate.iso.gz" -MyVmFolder "D:\VMs\myhome"
#>

param (
    [string]$IsoGzPath,
    [string]$VmName = "pfSense",
    [int]$CpuCount = 1,
    [int]$MemoryMB = 2048,
    [string]$WanNetName = "nat",
    [string]$DmzIntName = "intnetDMZ",
    [string]$LanIntName = "intnetLAN",
#    [string]$ExtraHostOnlyNet = "VirtualBox Host-Only Ethernet Adapter",
    [string]$BasePath,
    [string]$MyVmFolder
)

# ========== Funções ==========

function Ensure-7Zip {
    $fixedPath = "C:\Program Files\7-Zip\7z.exe"
    $localPath = "$PSScriptRoot\7z.exe"

    if (Test-Path $fixedPath) {
        Write-Host "✔ 7z.exe encontrado em '$fixedPath'."
        return $fixedPath
    } elseif (Test-Path $localPath) {
        Write-Host "✔ 7z.exe encontrado no diretório do script."
        return $localPath
    } else {
        Write-Error "❌ 7z.exe não encontrado. Instale o 7-Zip ou coloque o executável portátil no diretório do script."
        exit 1
    }
}

function Expand-IsoGz {
    param (
        [string]$inputPath,
        [string]$outputFolder,
        [string]$outputIsoName = "pfsense-installer-amd64.iso"
    )

    Write-Host "📦 Descompactando ISO $inputPath para pasta $outputFolder..."

    $sevenZipExe = Ensure-7Zip
    $args = "x", "-y", "-o$outputFolder", $inputPath
    $proc = Start-Process -FilePath $sevenZipExe -ArgumentList $args -NoNewWindow -Wait -PassThru

    if ($proc.ExitCode -ne 0) {
        Write-Error "❌ Erro ao descompactar a ISO (.gz)."
        exit $proc.ExitCode
    }

    $isoFiles = Get-ChildItem -Path $outputFolder -Filter *.iso -File | Sort-Object LastWriteTime -Descending
    if ($isoFiles.Count -eq 0) {
        Write-Error "❌ Nenhuma ISO encontrada após a descompactação."
        exit 1
    }

    $originalIsoPath = $isoFiles[0].FullName
    $targetIsoPath = Join-Path $outputFolder $outputIsoName

    if (Test-Path $targetIsoPath) {
        Remove-Item -Path $targetIsoPath -Force
    }

    Rename-Item -Path $originalIsoPath -NewName $outputIsoName -Force

    Write-Host "✅ ISO pronta: $targetIsoPath"
    return $targetIsoPath
}

function Create-Vm {
    param (
        [string]$vmName,
        [string]$isoPath,
        [int]$cpuCount,
        [int]$memoryMB,
        [string]$wanNet,
        [string]$dmzNet,
        [string]$lanNet,
        [string]$extraHostOnlyNet,
        [string]$vmFolder
    )

    Write-Host "🛠️ Criando VM '$vmName' na pasta '$vmFolder'..."

    if (-not (Test-Path $vmFolder)) {
        New-Item -ItemType Directory -Path $vmFolder -Force | Out-Null
    }

    & VBoxManage createvm --name $vmName --ostype "FreeBSD_64" --basefolder $vmFolder --register

    & VBoxManage modifyvm $vmName `
        --cpus $cpuCount --memory $memoryMB `
        --audio-enabled off --usb off --mouse ps2 `
        --nic1 "$wanNet" --nictype1 82540EM `
        --nic2 intnet --intnet2 "$dmzNet" --nictype2 82540EM `
        --nic3 intnet --intnet3 "$lanNet" --nictype3 82540EM `
#        --nic4 hostonly --hostonlyadapter4 "$extraHostOnlyNet" --nictype4 82540EM

    & VBoxManage storagectl $vmName --name "IDE Controller" --add ide
    & VBoxManage storageattach $vmName --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$isoPath"

    # Criar disco dentro da pasta da VM
    $vdiPath = Join-Path -Path (Join-Path $vmFolder $vmName) -ChildPath "$vmName.vdi"
    Write-Host "📄 Criando disco virtual de 20 GB em: $vdiPath"
    & VBoxManage createmedium disk --filename "$vdiPath" --size 20480 --format VDI

    & VBoxManage storagectl $vmName --name "SATA Controller" --add sata --controller IntelAhci
    & VBoxManage storageattach $vmName --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$vdiPath"

    Write-Host "✅ VM criada com disco e ISO montada."
    return $vdiPath
}

function Configure-PortForwarding {
    param (
        [string]$vmName
    )

    Write-Host "🌐 Configurando NAT port forwarding..."

    # Remover regras antigas, se existirem
    & VBoxManage modifyvm $vmName --natpf1 delete "ssh"   2>$null
    & VBoxManage modifyvm $vmName --natpf1 delete "http"  2>$null
    & VBoxManage modifyvm $vmName --natpf1 delete "https" 2>$null

    # Adicionar novas regras
    & VBoxManage modifyvm $vmName --natpf1 "ssh,tcp,,2222,,22"
    & VBoxManage modifyvm $vmName --natpf1 "http,tcp,,8080,,80"
    & VBoxManage modifyvm $vmName --natpf1 "https,tcp,,8443,,443"

    Write-Host "🔁 Regras criadas:"
    Write-Host " - SSH   → Host:2222 → Guest:22"
    Write-Host " - HTTP  → Host:8080 → Guest:80"
    Write-Host " - HTTPS → Host:8443 → Guest:443"
}

# ========== Execução Principal ==========

# BasePath padrão = pasta acima do script
if (-not $BasePath) {
    $BasePath = Split-Path $PSScriptRoot -Parent
}

# MyVmFolder padrão = mesma pasta do BasePath
if (-not $MyVmFolder) {
    $MyVmFolder = $BasePath
}

# IsoGzPath padrão
if (-not $IsoGzPath) {
    $IsoGzPath = Join-Path $BasePath "netgate-installer-amd64.iso.gz"
}

# 1. Descompactar ISO
$OutputIsoPath = Expand-IsoGz -inputPath $IsoGzPath -outputFolder $BasePath

# 2. Criar VM e disco
$vdiPath = Create-Vm -vmName $VmName -isoPath $OutputIsoPath -cpuCount $CpuCount -memoryMB $MemoryMB `
    -wanNet $WanNetName -dmzNet $DmzIntName -lanNet $LanIntName -extraHostOnlyNet $ExtraHostOnlyNet -vmFolder $MyVmFolder

# 3. Configurar port forwarding
Configure-PortForwarding -vmName $VmName

# 4. Final
Write-Host "`n✅ VM '$VmName' criada com sucesso e pronta para uso manual."
Write-Host "📎 ISO: $OutputIsoPath"
Write-Host "📂 Disco VDI: $vdiPath"
Write-Host "🌐 WAN (hostonly/NAT): $WanNetName"
Write-Host "🛡️ DMZ (intnet): $DmzIntName"
Write-Host "🏠 LAN (intnet): $LanIntName"
Write-Host "🔌 Extra Hostonly (NIC4): $ExtraHostOnlyNet"
Write-Host "📂 VM localizada em: $(Join-Path $MyVmFolder $VmName)"
Write-Host ""
Write-Host "🖥️  Ligue a VM '$VmName' no VirtualBox e prossiga com a instalação."
Write-Host ""
