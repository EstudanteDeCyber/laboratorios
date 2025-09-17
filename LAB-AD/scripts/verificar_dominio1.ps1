# VERIFICAR_DOMINIO_COMPACTADO.PS1
Write-Host "===== VERIFICAÇÃO DO DOMÍNIO AD/DNS =====" -ForegroundColor Cyan

$dominioEsperado = "lab.local"
$zonaReversaEsperada = "10.10.10.in-addr.arpa"

# Armazena resultados
$resultados = @()

function Adicionar-Resultado {
    param (
        [string]$Etapa,
        [string]$Descricao,
        [string]$Status,
        [string]$Detalhes
    )
    $resultados += [PSCustomObject]@{
        Etapa     = $Etapa
        Descricao = $Descricao
        Status    = $Status
        Detalhes  = $Detalhes
    }
}

function Testar-Comando {
    param (
        [string]$Etapa,
        [string]$Descricao,
        [ScriptBlock]$Comando
    )
    try {
        $output = & $Comando
        Adicionar-Resultado $Etapa $Descricao "OK" ($output | Out-String -Stream | Select-Object -First 1)
    } catch {
        Adicionar-Resultado $Etapa $Descricao "FALHA" ($_.Exception.Message -replace "`n.*", "")
    }
}

# TESTES

Testar-Comando "1" "Domínio AD (Get-ADDomain)" {
    Import-Module ActiveDirectory
    Get-ADDomain
}

Testar-Comando "2" "Controlador de Domínio (Get-ADDomainController)" {
    Get-ADDomainController
}

Testar-Comando "3" "DNS resolve domínio ($dominioEsperado)" {
    Resolve-DnsName $dominioEsperado
}

Testar-Comando "4" "Registro SRV LDAP" {
    Resolve-DnsName -Type SRV ("_ldap._tcp." + $dominioEsperado)
}

Testar-Comando "5" "Serviços DNS/NTDS/Netlogon" {
    $s = Get-Service -Name DNS, NTDS, Netlogon
    if ($s.Status -contains "Running") { return "SERVIÇOS OK" } else { throw "UM OU MAIS SERVIÇOS PARADOS" }
}

Testar-Comando "6" "Zonas DNS configuradas" {
    Get-DnsServerZone
}

Testar-Comando "7" "Zona reversa '$zonaReversaEsperada'" {
    $zonas = Get-DnsServerZone
    if ($zonas.ZoneName -contains $zonaReversaEsperada) {
        return "ZONA REVERSA PRESENTE"
    } else {
        throw "ZONA REVERSA NÃO ENCONTRADA"
    }
}

Testar-Comando "8" "Descoberta de DC via nltest" {
    nltest /dsgetdc:$dominioEsperado
}

# SAÍDA FINAL COMPACTADA
Write-Host "`n===== RESULTADO DA VERIFICAÇÃO =====" -ForegroundColor Cyan
$resultados | Sort-Object Etapa | Format-Table -AutoSize
