# Executar como administrador

Write-Host "Iniciando ajustes no Windows 11..." -ForegroundColor Cyan

# ---------------------------------------------
# 1. Remover o OneDrive completamente
# ---------------------------------------------

Write-Host "Removendo o OneDrive..." -ForegroundColor Yellow

# Finalizar qualquer processo do OneDrive
taskkill /f /im OneDrive.exe 2>$null

# Desinstalar OneDrive (versão Win32)
$onedriveSetupPath = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe"
if (Test-Path $onedriveSetupPath) {
    & $onedriveSetupPath /uninstall
} else {
    $onedriveSetupPath = "$env:SYSTEMROOT\System32\OneDriveSetup.exe"
    if (Test-Path $onedriveSetupPath) {
        & $onedriveSetupPath /uninstall
    }
}

# Remover app da Microsoft Store (versão UWP)
Get-AppxPackage *OneDrive* | Remove-AppxPackage -ErrorAction SilentlyContinue

# Remover diretorios residuais
Remove-Item "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:PROGRAMDATA\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue

# Limpar tarefas agendadas relacionadas ao OneDrive
Get-ScheduledTask | Where-Object { $_.TaskName -like "*OneDrive*" } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "OneDrive removido com sucesso." -ForegroundColor Green

# ---------------------------------------------
# 2. Desativar os Widgets (lado esquerdo da barra)
# ---------------------------------------------

Write-Host "Desativando os Widgets..." -ForegroundColor Yellow

# O valor 0 desativa os widgets
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -PropertyType DWORD -Force

# Tambem desativa via politica (GPO Local)
New-Item -Path "HKLM:\Software\Policies\Microsoft\Dsh" -Force | Out-Null
New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -PropertyType DWord -Value 0 -Force

Write-Host "Widgets desativados." -ForegroundColor Green

# ---------------------------------------------
# 3. Ajustar menu iniciar para o lado esquerdo
# ---------------------------------------------

Write-Host "Ajustando o menu iniciar para a esquerda..." -ForegroundColor Yellow

# Alinhar menu iniciar a esquerda
# Valor 0 = Esquerda | Valor 1 = Centro
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0 -PropertyType DWORD -Force

Write-Host "Menu iniciar ajustado para o lado esquerdo." -ForegroundColor Green

# ---------------------------------------------
# 4. Ajustar icones area de trabalho
# ---------------------------------------------

# Apagar os icones da area de trabalho
$desktopPath = [System.Environment]::GetFolderPath('Desktop')

# Remove todos os arquivos da area de trabalho (exceto pastas)
Get-ChildItem -Path $desktopPath -File | Remove-Item -Force

Write-Host "Icones da area de trabalho apagados."

# Criar um icone do Firefox em modo anonimo na area de trabalho
$firefoxPath = "C:\Program Files\Mozilla Firefox\private_browsing.exe"
$shortcutPath = "$desktopPath\Firefox Anonimo.lnk"

# Criar um objeto COM para criar o atalho
$WScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $WScriptShell.CreateShortcut($shortcutPath)

Write-Host "Icone do Firefox em modo anonimo criado na area de trabalho."

# ---------------------------------------------
# Clear firefox apos fechar
# ---------------------------------------------

# Verifica se o Firefox está instalado e se o perfil ainda não existe
$firefoxPath = "C:\Program Files\Mozilla Firefox\firefox.exe"
$firefoxProfilePath = "$env:APPDATA\Mozilla\Firefox\Profiles"

if ((Test-Path $firefoxPath) -and -not (Test-Path $firefoxProfilePath)) {
    Write-Host "Perfil do Firefox não encontrado. Iniciando Firefox para criar o perfil..." -ForegroundColor Yellow

    # Executa o Firefox normalmente para forçar criação do perfil padrão
    Start-Process -FilePath $firefoxPath
    Start-Sleep -Seconds 30  # Aumentando o tempo para 30 segundos para garantir que o Firefox crie o perfil

    # Encerra o Firefox, caso continue rodando
    Stop-Process -Name firefox -Force -ErrorAction SilentlyContinue

    Write-Host "Perfil criado." -ForegroundColor Green
}

function Set-FirefoxClearCookiesOnExit {
    # Caminho do perfil do Firefox
    $firefoxProfilePath = "C:\Users\vagrant\AppData\Roaming\Mozilla\Firefox\Profiles\"
    
    # Encontrar o perfil do Firefox (geralmente o perfil padrão é o "*default-release")
    $profile = Get-ChildItem -Path $firefoxProfilePath | Where-Object { $_.Name -like "*.default-release" }

    if ($profile) {
        $prefsFile = "$profile.FullName\prefs.js"
        
        # Verifica se o arquivo prefs.js existe
        if (Test-Path $prefsFile) {
            # Verificar se a configuração de limpeza de cookies ao fechar está definida
            $line = Get-Content $prefsFile | Select-String -Pattern "privacy.clearOnShutdown.cookies"

            if (-not $line) {
                # Adicionar configuração para limpar cookies ao fechar o Firefox
                Add-Content -Path $prefsFile -Value 'user_pref("privacy.clearOnShutdown.cookies", true);'
                Write-Host "Configuração para limpar cookies ao fechar o Firefox adicionada com sucesso." -ForegroundColor Green
            } else {
                Write-Host "A configuração para limpar cookies ao fechar já está presente." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Arquivo prefs.js não encontrado no perfil do Firefox." -ForegroundColor Red
        }
    } else {
        Write-Host "Perfil do Firefox não encontrado." -ForegroundColor Red
    }
}

# ---------------------------------------------
# 5. Ajustar bookmark firefox
# ---------------------------------------------

# Limpar os bookmarks do Firefox e deixar apenas o conteudo especificado
$firefoxProfilePath = "C:\Users\vagrant\AppData\Roaming\Mozilla\Firefox\Profiles\"

# Encontrar o perfil padrao do Firefox
$profile = Get-ChildItem -Path $firefoxProfilePath | Where-Object { $_.Name -like "*.default-release" }

if ($profile) {
    $bookmarksFilePath = "$profile.FullName\places.sqlite"
    
    # Verificar se o arquivo de bookmarks existe
    if (Test-Path $bookmarksFilePath) {
        
		# Comandos SQL a serem executados no SQLite
		$deleteSQLCommands = "DELETE FROM moz_bookmarks; DELETE FROM moz_places; DELETE FROM moz_historyvisits;"

		# Agora cria o comando sqlite3 com a variável
		$sqliteCmd = "sqlite3 $bookmarksFilePath '$($deleteSQLCommands)'"

		# Executar o comando SQLite para apagar
		Invoke-Expression $sqliteCmd
		        

        # Adicionar o bookmark especifico (voce pode querer ajustar isso conforme necessario)
        $bookmarkHTML = @"
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<!-- This is an automatically generated file.
     It will be read and overwritten.
     DO NOT EDIT! -->
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<meta http-equiv="Content-Security-Policy"
      content="default-src 'self'; script-src 'none'; img-src data: *; object-src 'none'"></meta>
<TITLE>Bookmarks</TITLE>
<H1>Menu de favoritos</H1>

<DL><p>
    <DT><H3 ADD_DATE="1758457185" LAST_MODIFIED="1758457719" PERSONAL_TOOLBAR_FOLDER="true">Barra de favoritos</H3>
    <DL><p>
        <DT><A HREF="http://10.10.10.30/" ADD_DATE="1758457456" LAST_MODIFIED="1758457456" ICON_URI="http://10.10.10.30/resources/7hg8x/welcome/keycloak/img/favicon.ico" ICON="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACOklEQVQ4ja2TPUwTcRjGf/e/O+hB21BahFYBB6oBY0wIRnfnIxoHFYPG6KaDu3Fw0UQnY2KYTNFEFkxMbmAwDA4ODGI0okgNtSGtRaBUr+19tHfnQDCYGB3wmd4n75P3K88Lu4S0k+i6fh049Rf9F8MwLv6xgK7r+4G3QPQfTS8ZhpHZJmJH4hYQrYfCfOo/wvLACADfUwOUT5zF6Tu4rbuv63rHbxNkMplrtm0/UBSFSaudOUfBHRzhYX6Gie6jtHT10CrLnPkwQyzUgu/7n1VVLf4qMD8/byYSifBs7iuX5vJEknsZ6utlqrfJo03B3Q2Fw2GVk611TmsWrusiy/LWCtPT05OxWCwMMLFcJhJqxezq416Ph+u6nG+zSAifRrPJc6eNXEOgqiqStHU+kU6nxyRJ4snHFebWTMzUAOe0Oh2OiWmauK7L7U6LBctHCXzurMs4joNlWdi2jdgObNsmmj7EgT2dJEMtmKZJs9lElmUCs4KXW+R9tYEiBEIIPM/D931ENpt9DDCaitIdbeeb0+Sl10YZFU3TqFar3HhXJNYZpxZIXJXXsG2bcrlMrVZDjI+PXy4UCpVIJMLNeIOKB5uux5SSBODZqkXRE2xGu7gSMtmnBgRBAICiKMgAw8PDG7lcblSsFViXNRYlDdQQ3a9f8LRkUesfQlEVxvKvWF3JUyqVloB8qVTK7nTiJHChHomzMnicaMMm+WaWcixFcfAYyfwC8cISwA+g3zCMyn+x8q6fadf4CaUa9pUKnnXCAAAAAElFTkSuQmCC">Welcome to Keycloak</A>
        <DT><A HREF="http://10.10.10.30:9000/" ADD_DATE="1758457474" LAST_MODIFIED="1758457476">Inbucket</A>
        <DT><A HREF="http://10.10.10.31/" ADD_DATE="1758457719" LAST_MODIFIED="1758457719">Portal de Exercicios</A>
    </DL><p>
</DL>
"@

        # Substituir o arquivo bookmarks com o novo conteudo
        $bookmarkFilePath = "$profile.FullName\bookmarks.html"
        Set-Content -Path $bookmarkFilePath -Value $bookmarkHTML

        Write-Host "Bookmarks do Firefox atualizados."
    } else {
        Write-Host "Arquivo 'places.sqlite' nao encontrado."
    }
} else {
    Write-Host "Perfil do Firefox nao encontrado."
}

# ---------------------------------------------
# Finalizacao
# ---------------------------------------------
Write-Host "`nTodas as alteracoes foram aplicadas." -ForegroundColor Cyan
Write-Host "Voce pode precisar reiniciar o computador para que tudo tenha efeito." -ForegroundColor Magenta