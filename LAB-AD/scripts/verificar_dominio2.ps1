# VERIFICAR_DOMINIO_COMPACTADO.PS1
Write-Host "===== VERIFICACAO DO DOMINIO AD/DNS =====" -ForegroundColor Cyan

# Configuracoes esperadas
$dominioEsperado = "lab.local"
$zonaReversaEsperada = "10.10.10.in-addr.arpa"

# Armazena resultados
$resultados = @()

# Funcao para adicionar resultados
function Adicionar-Resultado {
    param (
        [string]$Etapa,
        [string]$Descricao,
        [string]$Status,
        [string]$Detalhes
    )
    $script:resultados += [PSCustomObject]@{
        ETAPA     = $Etapa
        DESCRICAO = $Descricao.ToUpper()
        STATUS    = $Status.ToUpper()
        DETALHES  = $Detalhes.ToUpper()
    }
}

# Funcao para testar comandos
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

# INICIO DOS TESTES

Testar-Comando "1" "DOMINIO AD (GET-ADDOMAIN)" {
    Import-Module ActiveDirectory -ErrorAction Stop
    Get-ADDomain -ErrorAction Stop
}

Testar-Comando "2" "CONTROLADOR DE DOMINIO (GET-ADDOMAINCONTROLLER)" {
    Get-ADDomainController -ErrorAction Stop
}

Testar-Comando "3" "DNS RESOLVE DOMINIO ($dominioEsperado)" {
    Resolve-DnsName $dominioEsperado -ErrorAction Stop
}

Testar-Comando "4" "REGISTRO SRV LDAP (_LDAP._TCP.$dominioEsperado)" {
    Resolve-DnsName -Type SRV ("_ldap._tcp." + $dominioEsperado) -ErrorAction Stop
}

Testar-Comando "5" "SERVICOS DNS/NTDS/NETLOGON" {
    $s = Get-Service -Name DNS, NTDS, Netlogon -ErrorAction Stop
    if ($s.Status -contains "Running") {
        return "SERVICOS OK"
    } else {
        throw "UM OU MAIS SERVICOS PARADOS"
    }
}

Testar-Comando "6" "ZONAS DNS CONFIGURADAS (GET-DNSSERVERZONE)" {
    Get-DnsServerZone -ErrorAction Stop
}

Testar-Comando "7" "ZONA REVERSA '$zonaReversaEsperada'" {
    $zonas = Get-DnsServerZone -ErrorAction Stop
    if ($zonas.ZoneName -contains $zonaReversaEsperada) {
        return "ZONA REVERSA PRESENTE"
    } else {
        throw "ZONA REVERSA NAO ENCONTRADA"
    }
}

Testar-Comando "8" "DESCOBERTA DE DC VIA NLTEST" {
    nltest /dsgetdc:$dominioEsperado
}

# SAIDA FINAL COMPACTADA
Write-Host "`n===== RESULTADO DA VERIFICACAO =====" -ForegroundColor Cyan

if ($resultados.Count -gt 0) {
    $resultados | Sort-Object ETAPA | Format-Table -AutoSize
} else {
    Write-Host "NENHUM RESULTADO FOI COLETADO." -ForegroundColor Yellow
}
