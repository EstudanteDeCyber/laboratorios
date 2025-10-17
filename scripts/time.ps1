# Define a mensagem de ajuda e uso
$scriptName = $MyInvocation.MyCommand.Name
$helpMessage = @"
Uso: .\$scriptName .\meu-script-de-teste.ps1 -argumento1 "valor do argumento"

Descrição:
Mede o tempo de execução de um script PowerShell e seus argumentos, exibindo a saída no console.

"@

# Verifica se o script foi executado sem argumentos ou com o argumento 'help'
if ($args.Count -eq 0 -or $args[0] -eq "help") {
    Write-Host $helpMessage
    exit 1
}

# Lógica de argumentos robusta (permanece a mesma)
$ScriptToRun = $args[0]
$ArgumentsForScript = @()
if ($args.Count -gt 1) {
    $ArgumentsForScript = $args[1..($args.Count - 1)]
}

# Validação do caminho (permanece a mesma)
try {
    $scriptPath = Resolve-Path -Path $ScriptToRun -ErrorAction Stop
}
catch {
    Write-Host "Erro: Não foi possível encontrar o script em '$ScriptToRun'." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -Path $scriptPath -PathType Leaf)) {
    Write-Host "Erro: O arquivo de script não foi encontrado em '$scriptPath'." -ForegroundColor Red
    exit 1
}

Write-Host "Executando script: $scriptPath" -ForegroundColor Yellow
if ($ArgumentsForScript) {
    Write-Host "Com argumentos: $($ArgumentsForScript -join ' ')" -ForegroundColor Cyan
}

# --- MUDANÇA FINAL: Execução condicional dentro do Measure-Command ---
$executionTime = Measure-Command -Expression {
    # Verifica se a nossa lista de argumentos está realmente preenchida.
    # Um array não-vazio é avaliado como $true. Um array vazio é $false.
    if ($ArgumentsForScript) {
        # Se TEMOS argumentos, executa o script passando-os.
        & $scriptPath $ArgumentsForScript | Out-Default
    }
    else {
        # Se NÃO TEMOS argumentos, executa o script de forma limpa, sem nada extra.
        & $scriptPath | Out-Default
    }
}
Write-Host " "
Write-Host "`n--- Resultado ---"
Write-Host "Tempo de execução: $($executionTime.TotalSeconds) segundos = $($executionTime.TotalMinutes) minutos" -ForegroundColor Green
Write-Host " "
