
$chromePath = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
$chromeExtURL = "https://chromewebstore.google.com/detail/assinador-digital-do-brbj/oocinbphmhafgohfmjiakojglnpfkcmh?pli=1"
$javaURL = "https://javadl.oracle.com/webapps/download/AutoDL?xd_co_f=NzExNjUxYzgtYTk1ZS00NjBiLWE2ZjEtNTg4NDQ5Mzc5MTU1&BundleId=252322_68ce765258164726922591683c51982c"
$javaInstaller = "$env:TEMP\java-installer.exe"
$jarURL = "https://sjb.brb.com.br/assinador/sjb-instalador-assinador-1.3.0.jar"
$jarPath = "$env:TEMP\sjb-instalador-assinador.jar"
$brbjusURL = "https://brbjus-tjpb.brb.com.br/"
$testadorURL = "https://sjb.brb.com.br/assinador/"
$shortcutPath = "$env:Public\Desktop\Acessar BRBJUS.lnk"

# Função para baixar arquivos
function Download-File($url, $dest) {
    if (Test-Path $dest) {
        try {
            Remove-Item $dest -Force -ErrorAction Stop
        } catch {
            Write-Host "⚠️ Arquivo em uso: $dest" -ForegroundColor Yellow
        }
    }
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

# Verificar se o Chrome está instalado
if (-Not (Test-Path $chromePath)) {
    Write-Host "❌ Google Chrome não encontrado. Instale-o antes de continuar." -ForegroundColor Red
    exit 1
}

# Etapa 1: Atualizar o Chrome (opcional)
Write-Host "✅ Verificando atualização do Google Chrome..."
$updatePath = "$env:ProgramFiles\Google\Update\GoogleUpdate.exe"
if (Test-Path $updatePath) {
    Start-Process $updatePath -ArgumentList "/ua /installsource scheduler" -Wait
} else {
    Write-Host "⚠️ Atualizador do Chrome não encontrado. Continuando..." -ForegroundColor Yellow
}

# Etapa 2: Abrir link da extensão no Chrome para o usuário instalar manualmente
Write-Host "🌐 Abrindo link da extensão BRBJUS no Chrome para instalação..."
Start-Process -FilePath $chromePath -ArgumentList $chromeExtURL

function Esperar-ChromeFechar {
    Write-Host "`n⏳ Aguarde até que o navegador seja fechado após instalar a extensão. Pressione Enter para continuar quando estiver pronto..." -ForegroundColor Cyan
    Read-Host
}

Esperar-ChromeFechar

# Etapa 3: Verificar/criar pasta TEMP
if (-Not (Test-Path $env:TEMP)) {
    Write-Host "📁 Criando pasta TEMP..."
    New-Item -Path $env:TEMP -ItemType Directory -Force | Out-Null
}

# Etapa 4: Baixar e instalar o Java
Write-Host "☕ Baixando instalador do Java..."
Download-File $javaURL $javaInstaller

Write-Host "📦 Instalando Java em modo silencioso..."
try {
    Start-Process -FilePath $javaInstaller -ArgumentList "/s" -Wait -ErrorAction Stop
} catch {
    Write-Host "⚠️ Erro ao instalar Java. Pode já estar instalado ou o instalador falhou." -ForegroundColor Yellow
}

# Etapa 5: Verificar se o Java foi instalado e está no PATH
function Test-Java {
    try {
        $java = & java -version 2>&1
        return $true
    } catch {
        return $false
    }
}

if (-Not (Test-Java)) {
    # Tentar localizar instalação do Java
    $possiblePaths = @(
        "${env:ProgramFiles}\Java\jre*\bin\java.exe",
        "${env:ProgramFiles(x86)}\Java\jre*\bin\java.exe"
    )

    $foundJava = $null
    foreach ($path in $possiblePaths) {
        $match = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($match) {
            $foundJava = $match.FullName
            break
        }
    }

    if ($foundJava) {
        # Adicionar ao PATH permanentemente
        Write-Host "➕ Java encontrado em: $foundJava"
        $javaDir = Split-Path $foundJava -Parent
        $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
        if ($currentPath -notlike "*$javaDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$javaDir", [EnvironmentVariableTarget]::Machine)
            Write-Host "✅ Caminho do Java adicionado ao PATH (permanente)."
        }
    } else {
        Write-Host "❌ Java não foi detectado. Instale manualmente ou reinicie o PC." -ForegroundColor Red
        exit 1
    }
}

# Etapa 6: Baixar e executar assinador BRB
Write-Host "📥 Baixando instalador do assinador BRB..."
Download-File $jarURL $jarPath

Write-Host "🚀 Executando o instalador do assinador com Java..."
Start-Process -FilePath "java" -ArgumentList "-jar `"$jarPath`"" -Wait

# Fechar apenas as janelas do navegador Google Chrome
Write-Host "🚪 Fechando janelas do navegador Chrome..."
$chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
if ($chromeProcesses) {
    foreach ($process in $chromeProcesses) {
        try {
            if ($process.MainModule.FileName -like "*\Google\Chrome\Application\chrome.exe") {
                if ($process.MainWindowTitle -notlike "*Google Chat*") {
                    $process.CloseMainWindow() | Out-Null
                    Start-Sleep -Milliseconds 500
                    if (!$process.HasExited) {
                        $process.Kill()
                    }
                }
            }
        } catch {
            Write-Warning "Erro ao tentar fechar processo Chrome (PID: $($process.Id)): $_"
        }
    }
    Write-Host "✅ Navegador Chrome fechado com sucesso."
} else {
    Write-Host "ℹ️ Nenhum processo do Google Chrome encontrado."
}

# Etapa 8: Criar atalho e abrir BRBJUS + testador
Write-Host "🔗 Criando atalho na área de trabalho..."
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $chromePath
$Shortcut.Arguments = "--new-window $brbjusURL"
$Shortcut.IconLocation = "$chromePath"
$Shortcut.Save()

# Abrir BRBJUS e testador em abas separadas
Write-Host "🌐 Abrindo BRBJUS e testador no navegador..."
Start-Process -FilePath $chromePath -ArgumentList "--new-window $brbjusURL $testadorURL"

Write-Host "`n✅ Processo concluído com sucesso!" -ForegroundColor Green
