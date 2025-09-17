# EXECUTAR ESTE SCRIPT COMO ADMINISTRADOR
Set-ExecutionPolicy Bypass -Scope Process -Force

Write-Host "`n=== INVENTARIO COMPLETO DE SOFTWARES INSTALADOS NO WINDOWS ===`n"

# DATA E HORA DA COLETA
$dataColeta = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# ========================
# FUNCAO PARA REGISTRO
# ========================
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

# ========================
# FUNCAO PARA PACOTES (GET-PACKAGE)
# ========================
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

# ========================
# FUNCAO PARA STORE (APPX/UWP)
# ========================
function GET-SOFTWARE-STORE {
    param($DataColeta)

    Get-AppxPackage | ForEach-Object {
        [PSCustomObject]@{
            NOME              = $_.Name
            VERSAO            = $_.Version.ToString()
            FABRICANTE        = $_.Publisher
            LOCAL_INSTALACAO  = $_.InstallLocation
            CODIGO            = $_.PackageFamilyName
            ORIGEM            = "STORE"
            DATA_COLETA       = $DataColeta
        }
    }
}

# ========================
# COLETA DOS DADOS
# ========================
Write-Host "[*] COLETANDO SOFTWARES DO REGISTRO..."
$paths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
)
$regSoftwares = foreach ($path in $paths) { GET-SOFTWARE-REGISTRO -Path $path -DataColeta $dataColeta }

Write-Host "[*] COLETANDO SOFTWARES VIA GET-PACKAGE..."
$pkgSoftwares = GET-SOFTWARE-PACKAGE -DataColeta $dataColeta

Write-Host "[*] COLETANDO APLICATIVOS DA MICROSOFT STORE..."
$storeSoftwares = GET-SOFTWARE-STORE -DataColeta $dataColeta

# UNIFICAR INVENTARIO
$softwares = $regSoftwares + $pkgSoftwares + $storeSoftwares

# REMOVER DUPLICADOS (NOME + VERSAO + ORIGEM)
$softwares = $softwares | Sort-Object NOME, VERSAO, ORIGEM -Unique

# ========================
# EXPORTAR RESULTADOS
# ========================
$desktop = [Environment]::GetFolderPath("Desktop")
$csvFile = Join-Path $desktop "inventario_softwares.csv"
$htmlFile = Join-Path $desktop "inventario_softwares.html"

# EXPORTAR PARA CSV
$softwares | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8

# EXPORTAR PARA HTML COM ESTILO
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

$header = "<h2>INVENTARIO COMPLETO DE SOFTWARES</h2><p>DATA DA COLETA: $dataColeta</p>"

$softwares | ConvertTo-Html -Property NOME, VERSAO, FABRICANTE, LOCAL_INSTALACAO, CODIGO, ORIGEM, DATA_COLETA -Head $style -Title "INVENTARIO DE SOFTWARES" -PreContent $header |
    Out-File -FilePath $htmlFile -Encoding UTF8

Write-Host "[+] INVENTARIO COMPLETO GERADO COM SUCESSO!"
Write-Host "[+] ARQUIVOS DISPONIVEIS:"
Write-Host "    - $csvFile"
Write-Host "    - $htmlFile"
Write-Host "`nTOTAL DE SOFTWARES ENCONTRADOS: $($softwares.Count)"
Write-Host "=== PROCESSO CONCLUIDO ==="
