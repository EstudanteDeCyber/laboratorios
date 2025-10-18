# Define a mensagem de ajuda e uso
$scriptName = $MyInvocation.MyCommand.Name
$helpMessage = @"
Uso:
  .\$scriptName .\meu-script.ps1 -arg1 "valor"
  .\$scriptName vagrant -d destroy --vagrantfile=Vagrantfile_custom
Descrição:
Mede o tempo de execução de um script PowerShell ou comando externo (ex: vagrant, docker), exibindo a saída no console.
"@

# Verifica se o script foi executado sem argumentos ou com o argumento 'help'
if ($args.Count -eq 0 -or $args[0] -eq "help") {
    Write-Host $helpMessage
    exit 1
}

# Diretório onde está o script atual
$CurrentScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

# Coleta o primeiro argumento (pode ser script ou comando)
$FirstArg = $args[0]
$RemainingArgs = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

# Inicializa variável de execução
$runAsScript = $false
$scriptPath = $null

# Verifica se é um script existente
try {
    # Se for caminho relativo, ajusta para o diretório do script atual
    if (-not [System.IO.Path]::IsPathRooted($FirstArg)) {
        $FirstArg = Join-Path -Path $CurrentScriptDirectory -ChildPath $FirstArg
    }
    # Tenta resolver o caminho do script
    $scriptPath = Resolve-Path -Path $FirstArg -ErrorAction Stop
    # Verifica se é um arquivo mesmo
    if (Test-Path -Path $scriptPath -PathType Leaf) {
        $runAsScript = $true
    }
}
catch {
    # Se falhar, vamos tratar como comando externo
    $runAsScript = $false
}

# --- Execução com tempo medido ---
$executionTime = Measure-Command {
    try {
        if ($runAsScript) {
            Write-Host "Executando script: $scriptPath" -ForegroundColor Yellow
            if ($RemainingArgs) {
                Write-Host "Com argumentos: $($RemainingArgs -join ' ')" -ForegroundColor Cyan
                & $scriptPath @RemainingArgs | Out-Default
            }
            else {
                & $scriptPath | Out-Default
            }
        }
        else {
            # Trata como comando genérico
            Write-Host "Executando comando: $FirstArg $($RemainingArgs -join ' ')" -ForegroundColor Yellow
            & $FirstArg @RemainingArgs | Out-Default
        }
    }
    catch {
        Write-Host "`nErro durante a execução:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

# --- Resultado ---
Write-Host "`n--- Resultado ---"
Write-Host "Tempo de execução: $($executionTime.TotalSeconds) segundos = $($executionTime.TotalMinutes) minutos" -ForegroundColor Green