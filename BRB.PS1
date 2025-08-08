# Reexecuta o script como Administrador se não estiver elevado
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Reexecutando como administrador..."
    $CommandLine = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb runAs -ArgumentList $CommandLine
    exit
}

$chromePath = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chromePath)) {
    $chromePath = "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe"
}
if (-not (Test-Path $chromePath)) {
    Write-Host "❌ Google Chrome não encontrado. Instale-o antes de continuar." -ForegroundColor Red
    exit 1
}

$chromeExtURL = "https://chromewebstore.google.com/detail/assinador-digital-do-brbj/oocinbphmhafgohfmjiakojglnpfkcmh?pli=1"
$jarURL = "https://sjb.brb.com.br/assinador/sjb-instalador-assinador-1.3.0.jar"
$jarPath = "$env:TEMP\sjb-instalador-assinador.jar"
$brbjusURL = "https://brbjus-tjpb.brb.com.br/"
$testadorURL = "https://sjb.brb.com.br/assinador/"
$shortcutPath = "$env:Public\Desktop\Acessar BRBJUS.lnk"

# ===========================
# FUNÇÕES INTEGRADAS DO SCRIPT 1 (JAVA)
# ===========================

function Write-Log($msg) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $msg"
}

function Remove-JavaX86 {
    Write-Log "Removendo instalações existentes do Java..."
    $javaApps = Get-WmiObject -Class Win32_Product | Where-Object {
        ($_.Name -match "Java" -or $_.Name -match "JRE" -or $_.Name -match "OpenJDK" -or $_.Name -match "Liberica") -and
        $_.Name -notlike "*Liberica JRE 8 Full (64-bit)*"
    }
    foreach ($app in $javaApps) {
        Write-Log "Desinstalando: $($app.Name)"
        try {
            $app.Uninstall() | Out-Null
            Write-Log "Removido com sucesso: $($app.Name)"
        } catch {
            Write-Log "Erro ao remover $($app.Name): $_"
        }
    }
}

function Install-JavaJRE {
    $javaUrl = "https://download.bell-sw.com/java/8u462+11/bellsoft-jre8u462+11-windows-amd64-full.msi"
    $installerPath = "$env:TEMP\bellsoft-jre8u462.msi"
    Write-Log "Baixando instalador do BellSoft Java JRE 8u462..."
    Invoke-WebRequest -Uri $javaUrl -OutFile $installerPath
    if (Test-Path $installerPath) {
        Write-Log "Instalador baixado com sucesso. Instalando em modo silencioso..."
        $installArgs = "/i `"$installerPath`" /qn /norestart"
        Start-Process "msiexec.exe" -ArgumentList $installArgs -Wait -NoNewWindow
        Write-Log "Instalação do Java concluída."
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    } else {
        Write-Log "Erro: Falha ao baixar o instalador. Verifique a URL."
    }
}

# ===========================
# FUNÇÕES ORIGINAIS DO SCRIPT 2
# ===========================

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

# Verificar atualização do Chrome (opcional)
Write-Host "✅ Verificando atualização do Google Chrome..." 
$updatePath = "$env:ProgramFiles\Google\Update\GoogleUpdate.exe"
if (Test-Path $updatePath) {
    Start-Process $updatePath -ArgumentList "/ua /installsource scheduler" -Wait
} else {
    Write-Host "⚠️ Atualizador do Chrome não encontrado. Continuando..." -ForegroundColor Yellow
}

# ===========================
# SELEÇÃO DE PERFIL DO CHROME
# ===========================

$chromeUserDataPath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
if (-not (Test-Path $chromeUserDataPath)) {
    Write-Host "❌ Diretório de perfis do Chrome não encontrado." -ForegroundColor Red
    exit 1
}

$profiles = Get-ChildItem -Path $chromeUserDataPath -Directory |
    Where-Object { $_.Name -like "Profile *" -or $_.Name -eq "Default" }

if ($profiles.Count -eq 0) {
    Write-Host "❌ Nenhum perfil encontrado no Chrome." -ForegroundColor Red
    exit 1
}

if ($profiles.Count -eq 1) {
    $perfilSelecionado = $profiles[0].Name
    Write-Host "✅ Apenas um perfil encontrado: $perfilSelecionado"
} else {
    Write-Host "Perfis disponíveis no Chrome:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $profiles.Count; $i++) {
        $profileName = $profiles[$i].Name
        $prefFile = Join-Path $profiles[$i].FullName "Preferences"
        $displayName = $profileName
        $email = ""
        if (Test-Path $prefFile) {
            try {
                $json = Get-Content $prefFile -Raw | ConvertFrom-Json

                $friendlyName = $json.profile.name
                if ($friendlyName) { $displayName += " (`"$friendlyName`")" }

                if ($json.account_info -and $json.account_info.Count -gt 0) {
                    $email = $json.account_info[0].email
                } elseif ($json.gaia_info.email) {
                    $email = $json.gaia_info.email
                } elseif ($json.profile.email) {
                    $email = $json.profile.email
                }
            } catch {
                $email = ""
            }
        }

        if ($email) {
            Write-Host "$($i + 1)) $displayName - 📧 $email"
        } else {
            Write-Host "$($i + 1)) $displayName"
        }
    }

    do {
        $escolha = Read-Host "Digite o número do perfil que deseja usar"
        $valido = ($escolha -match '^\d+$') -and ([int]$escolha -ge 1) -and ([int]$escolha -le $profiles.Count)
        if (-not $valido) {
            Write-Host "❌ Opção inválida." -ForegroundColor Red
        }
    } while (-not $valido)

    $perfilSelecionado = $profiles[[int]$escolha - 1].Name
    Write-Host "✅ Perfil selecionado: $perfilSelecionado"
}

# Etapa 2: Abrir link da extensão no Chrome para o usuário instalar manualmente
Write-Host "🌐 Abrindo link da extensão BRBJUS no perfil '$perfilSelecionado' para instalação..." 
Start-Process -FilePath $chromePath -ArgumentList "--profile-directory=`"$perfilSelecionado`" $chromeExtURL"

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

# ===========================
# INSTALAÇÃO DO JAVA (USANDO FUNÇÕES DO SCRIPT 1)
# ===========================

Write-Log "=== INÍCIO DA INSTALAÇÃO/ATUALIZAÇÃO DO JAVA ==="
Remove-JavaX86
Install-JavaJRE
Write-Log "=== JAVA INSTALADO COM SUCESSO ==="

# ===========================
# CONTINUAÇÃO DO SCRIPT 2 ORIGINAL
# ===========================

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
                $process.CloseMainWindow() | Out-Null
                Start-Sleep -Milliseconds 500
                if (!$process.HasExited) {
                    $process.Kill()
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

# Etapa 8: Criar atalho e abrir BRBJUS + testador no perfil selecionado
Write-Host "🔗 Criando atalho na área de trabalho..."
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $chromePath
$Shortcut.Arguments = "--profile-directory=`"$perfilSelecionado`" --new-window $brbjusURL"
$Shortcut.IconLocation = "$chromePath"
$Shortcut.Save()

# Abrir BRBJUS e testador em abas separadas no perfil selecionado
Write-Host "🌐 Abrindo BRBJUS e testador no perfil '$perfilSelecionado'..."
Start-Process -FilePath $chromePath -ArgumentList "--profile-directory=`"$perfilSelecionado`" --new-window $brbjusURL $testadorURL"

Write-Host "`n✅ Processo concluído com sucesso!" -ForegroundColor Green
