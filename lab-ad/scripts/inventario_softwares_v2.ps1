# EXECUTAR ESTE SCRIPT COMO ADMINISTRADOR
Set-ExecutionPolicy Bypass -Scope Process -Force

$hostname = $env:COMPUTERNAME
$dataColeta = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

Write-Host "`n=== INVENTARIO COMPLETO DE SOFTWARES INSTALADOS NO WINDOWS ===`n"

# FUNCAO PARA REGISTRO
function GET-SOFTWARE-REGISTRO {
    param($Path, $DataColeta)
    if (Test-Path $Path) {
        Get-ChildItem $Path | ForEach-Object {
            $item = Get-ItemProperty $_.PSPath
            if ($item.DisplayName) {
                [PSCustomObject]@{
                    NOME              = $item.DisplayName
                    VERSAO            = $item.DisplayVersion
                    FABRICANTE        = $item.Publisher
                    LOCAL_INSTALACAO  = $item.InstallLocation
                    CODIGO            = $item.PSChildName
                    ORIGEM            = "REGISTRO"
                    DATA_COLETA       = $DataColeta
                }
            }
        }
    }
}

# FUNCAO PARA PACOTES GET-PACKAGE
function GET-SOFTWARE-PACKAGE {
    param($DataColeta)
    Get-Package | ForEach-Object {
        [PSCustomObject]@{
            NOME              = $_.Name
            VERSAO            = $_.Version.ToString()
            FABRICANTE        = $_.ProviderName
            LOCAL_INSTALACAO  = $null
            CODIGO            = $_.Id
            ORIGEM            = "PACKAGE"
            DATA_COLETA       = $DataColeta
        }
    }
}

# FUNCAO PARA APLICATIVOS STORE (UWP) COM NOME AMIGAVEL
function GET-SOFTWARE-STORE {
    param($DataColeta)
    Get-AppxPackage -AllUsers | ForEach-Object {
        $nomeAmigavel = ($_.InstallLocation | Get-Item | Get-AppxPackageManifest).Package.Properties.PublisherDisplayName 2>$null
        if (!$nomeAmigavel) { $nomeAmigavel = $_.Name }
        [PSCustomObject]@{
            NOME              = $nomeAmigavel
            VERSAO            = $_.Version.ToString()
            FABRICANTE        = $_.Publisher
            LOCAL_INSTALACAO  = $_.InstallLocation
            CODIGO            = $_.PackageFamilyName
            ORIGEM            = "STORE"
            DATA_COLETA       = $DataColeta
        }
    }
}

Write-Host "[*] COLETANDO SOFTWARES DO REGISTRO..."
$paths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
)
$regSoftwares = foreach ($p in $paths) { GET-SOFTWARE-REGISTRO -Path $p -DataColeta $dataColeta }

Write-Host "[*] COLETANDO SOFTWARES VIA GET-PACKAGE..."
$pkgSoftwares = GET-SOFTWARE-PACKAGE -DataColeta $dataColeta

Write-Host "[*] COLETANDO APLICATIVOS DA MICROSOFT STORE..."
$storeSoftwares = GET-SOFTWARE-STORE -DataColeta $dataColeta

# UNIFICAR E ORDENAR POR ORIGEM
$softwares = $regSoftwares + $pkgSoftwares + $storeSoftwares
$softwares = $softwares | Sort-Object ORIGEM, NOME, VERSAO -Unique

# DEFINIR NOMES DE ARQUIVOS
$desktop = [Environment]::GetFolderPath("Desktop")
$baseName = "INVENTARIO_${hostname}_${dataColeta}"
$csvFile = Join-Path $desktop "${baseName}.csv"
$htmlFile = Join-Path $desktop "${baseName}.html"

# EXPORTAR CSV
$softwares | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8

# EXPORTAR HTML COM ESTILO E CABEÇALHO
$style = @"
<style>
body { font-family: Arial, sans-serif; margin: 20px; }
h2 { color: #2E86C1; }
p { font-size: 14px; color: #555; }
table { border-collapse: collapse; width: 100%; margin-top: 20px; }
th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
th { background-color: #2E86C1; color: white; }
tr:nth-child(even) { background-color: #f2f2f2; }
</style>
"@

$header = "<h2>INVENTARIO COMPLETO DE SOFTWARES</h2><p>HOST: $hostname<br>DATA DA COLETA: $dataColeta</p>"

$softwares | ConvertTo-Html -Property NOME, VERSAO, FABRICANTE, LOCAL_INSTALACAO, CODIGO, ORIGEM, DATA_COLETA -Head $style -Title "INVENTARIO DE SOFTWARES" -PreContent $header |
    Out-File -FilePath $htmlFile -Encoding UTF8

Write-Host "[+] INVENTARIO COMPLETO GERADO COM SUCESSO!"
Write-Host "[+] ARQUIVOS DISPONIVEIS:"
Write-Host "    - $csvFile"
Write-Host "    - $htmlFile"
Write-Host "`nTOTAL DE SOFTWARES ENCONTRADOS: $($softwares.Count)"
Write-Host "=== PROCESSO CONCLUIDO ==="
