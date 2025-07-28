$ChromePath = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
$ChromeExtId = "oocinbphmhafgohfmjiakojglnpfkcmh"
$ChromeExtUpdateURL = "https://clients2.google.com/service/update2/crx"

$JavaURL = "https://javadl.oracle.com/webapps/download/AutoDL?xd_co_f=NzExNjUxYzgtYTk1ZS00NjBiLWE2ZjEtNTg4NDQ5Mzc5MTU1&BundleId=252322_68ce765258164726922591683c51982c"
$JavaInstaller = "$env:TEMP\java-installer.exe"

$JarURL = "https://sjb.brb.com.br/assinador/sjb-instalador-assinador-1.3.0.jar"
$JarPath = "$env:TEMP\sjb-instalador-assinador.jar"

$BRBJusURL = "https://brbjus-tjpb.brb.com.br/"
$ShortcutPath = "$env:Public\Desktop\Acessar BRBJUS.lnk"

# Função para baixar arquivos
function Download-File($url, $dest) {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

# Verificar se o Chrome está instalado
if (-Not (Test-Path $ChromePath)) {
    Write-Host "❌ Google Chrome não encontrado. Instale-o antes de continuar." -ForegroundColor Red
    exit 1
}

# Verificar se o Chrome está atualizado
Write-Host "✅ Verificando atualização do Google Chrome..."
$ChromeVer = & "$ChromePath" --version
$UpdatePath = "$env:ProgramFiles\Google\Update\GoogleUpdate.exe"
if (Test-Path $UpdatePath) {
    Write-Host "🔄 Atualizando Google Chrome (se necessário)..."
    Start-Process $UpdatePath -ArgumentList "/ua /installsource scheduler" -Wait
} else {
    Write-Host "⚠️ Atualizador do Chrome não encontrado. Pular atualização." -ForegroundColor Yellow
}

# Instalar extensão via política local
Write-Host "📦 Forçando instalação da extensão BRBJUS no Chrome..."
$RegPath = "HKLM:\Software\Policies\Google\Chrome\ExtensionInstallForcelist"
if (-not (Test-Path $RegPath)) {
    New-Item -Path "HKLM:\Software\Policies\Google" -Name "Chrome" -Force | Out-Null
    New-Item -Path "HKLM:\Software\Policies\Google\Chrome" -Name "ExtensionInstallForcelist" -Force | Out-Null
}
Set-ItemProperty -Path $RegPath -Name "1" -Value "$ChromeExtId;$ChromeExtUpdateURL"

# Baixar e instalar o Java
Write-Host "☕ Baixando instalador do Java..."
Download-File $JavaURL $JavaInstaller
Write-Host "📦 Instalando Java em modo silencioso..."
Start-Process -FilePath $JavaInstaller -ArgumentList "/s" -Wait

# Baixar e executar o assinador BRB
Write-Host "📥 Baixando o instalador do assinador BRB..."
Download-File $JarURL $JarPath
Write-Host "🚀 Executando o instalador do assinador com Java..."
Start-Process -FilePath "java" -ArgumentList "-jar `"$JarPath`"" -Wait

# Criar atalho na área de trabalho
Write-Host "🔗 Criando atalho para o BRBJUS na área de trabalho..."
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $ChromePath
$Shortcut.Arguments = "--new-window $BRBJusURL"
$Shortcut.IconLocation = "$ChromePath"
$Shortcut.Save()

# Abrir link no Chrome
Write-Host "🌐 Abrindo BRBJUS no navegador..."
Start-Process -FilePath $ChromePath -ArgumentList "--new-window $BRBJusURL"

Write-Host "`n✅ Processo concluído com sucesso!" -ForegroundColor Green
