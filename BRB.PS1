$ChromePath = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
$ExtURL = "https://chromewebstore.google.com/detail/assinador-digital-do-brbj/oocinbphmhafgohfmjiakojglnpfkcmh"

$JavaURL = "https://javadl.oracle.com/webapps/download/AutoDL?xd_co_f=NzExNjUxYzgtYTk1ZS00NjBiLWE2ZjEtNTg4NDQ5Mzc5MTU1&BundleId=252322_68ce765258164726922591683c51982c"
$JavaInstaller = "$env:TEMP\java-installer.exe"

$JarURL = "https://sjb.brb.com.br/assinador/sjb-instalador-assinador-1.3.0.jar"
$JarPath = "$env:TEMP\sjb-instalador-assinador.jar"

$BRBJusURL = "https://brbjus-tjpb.brb.com.br/"
$TestadorURL = "https://sjb.brb.com.br/assinador/"
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

# Abrir extensão no navegador para o usuário instalar manualmente
Write-Host "🧩 Abrindo a extensão do BRB para instalação manual..."
Start-Process -FilePath $ChromePath -ArgumentList "--new-window $ExtURL"

Write-Host ""
Write-Host "⚠️ Aguarde até o usuário instalar a extensão e fechar o navegador." -ForegroundColor Yellow
Write-Host "🔒 Pressione [ENTER] SOMENTE após fechar o Chrome."
Read-Host "⏳"

# Criar pasta TEMP (se não existir)
if (-Not (Test-Path $env:TEMP)) {
    New-Item -ItemType Directory -Path $env:TEMP | Out-Null
}

# Baixar e instalar o Java
Write-Host "☕ Baixando instalador do Java..."
Download-File $JavaURL $JavaInstaller
Write-Host "📦 Instalando Java em modo silencioso..."
Start-Process -FilePath $JavaInstaller -ArgumentList "/s" -Wait

# Verificar se o java está no PATH
if (-not (Get-Command "java.exe" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Java não foi detectado no PATH. Reinicie o PC e tente novamente." -ForegroundColor Red
    exit 1
}

# Baixar e executar o assinador BRB
Write-Host "📥 Baixando o instalador do assinador BRB..."
Download-File $JarURL $JarPath
Write-Host "🚀 Executando o instalador do assinador com Java..."
Start-Process -FilePath "java" -ArgumentList "-jar `"$JarPath`"" -Wait

# Criar atalho para o BRBJUS na área de trabalho
Write-Host "🔗 Criando atalho para o BRBJUS na área de trabalho..."
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $ChromePath
$Shortcut.Arguments = "--new-window $BRBJusURL"
$Shortcut.IconLocation = "$ChromePath"
$Shortcut.Save()

# Abrir o site do BRBJUS
Write-Host "🌐 Abrindo o site do BRB..."
Start-Process -FilePath $ChromePath -ArgumentList "--new-window $BRBJusURL"

# Abrir o testador do assinador
Write-Host "🧪 Abrindo o testador do assinador..."
Start-Process -FilePath $ChromePath -ArgumentList "--new-window $TestadorURL"

Write-Host "`n✅ Instalação concluída com sucesso!" -ForegroundColor Green
