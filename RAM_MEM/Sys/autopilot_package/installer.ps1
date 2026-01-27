# installer.ps1
# Запускается от имени администратора.
param(
    [string]$installPath = "B:\CORE\autopilot_setup",
    [string]$sandboxPath = "B:\CORE",
    [switch]$registerService = $true
)

function Write-Log($m){ Write-Host "$(Get-Date -Format s) - $m" }

Write-Log "Начинаем установку Autopilot..."
if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
    Write-Log "Создана папка $installPath"
}

# Проверка Python
$pythonExe = "python"
try {
    $pyver = & $pythonExe --version 2>&1
    Write-Log "Найден Python: $pyver"
} catch {
    Write-Log "Python не найден в PATH. Пожалуйста, установи Python 3.12 и добавь в PATH."
    exit 1
}

$venvPath = Join-Path $installPath "venv"
if (-not (Test-Path $venvPath)) {
    Write-Log "Создаём виртуальное окружение..."
    & $pythonExe -m venv $venvPath
}

$pip = Join-Path $venvPath "Scripts\pip.exe"
$python = Join-Path $venvPath "Scripts\python.exe"

Write-Log "Устанавливаем зависимости (pip). Это может занять время..."
& $pip install --upgrade pip
& $pip install -r (Join-Path $installPath "requirements.txt")

# Создаём структуру sandbox
if (-not (Test-Path $sandboxPath)) {
    New-Item -ItemType Directory -Path $sandboxPath -Force | Out-Null
    Write-Log "Создана папка $sandboxPath"
}
$dirs = @("autopilot_data","models","logs","gestures","config")
foreach ($d in $dirs) {
    $p = Join-Path $sandboxPath $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

# Создаём .env
$token = [System.Guid]::NewGuid().ToString("N")
$pin = (Get-Random -Minimum 100000 -Maximum 999999)
$envContent = @"
AUTOPILOT_TOKEN=$token
ADMIN_PIN=$pin
SANDBOX_PATH=$sandboxPath
DB_PASSWORD=ELARiON
DEFAULT_ROLE=guest
DEFAULT_LLM=llama3.1:8b
KILL_HOTKEY=ctrl+-+delete
"@
$envPath = Join-Path $installPath ".env"
$envContent | Out-File -FilePath $envPath -Encoding utf8

Write-Log "Файл .env создан. AUTOPILOT_TOKEN и ADMIN_PIN сгенерированы."
Write-Log "AUTOPILOT_TOKEN: $token"
Write-Log "ADMIN_PIN: $pin"

# Попытка установки NSSM для регистрации службы
if ($registerService) {
    Write-Log "Попытка зарегистрировать службу через NSSM..."
    $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
    $nssmZip = Join-Path $installPath "nssm.zip"
    try {
        Invoke-WebRequest -Uri $nssmUrl -OutFile $nssmZip -UseBasicParsing
        Expand-Archive -LiteralPath $nssmZip -DestinationPath (Join-Path $installPath "nssm") -Force
        $nssmExe = Get-ChildItem -Path (Join-Path $installPath "nssm") -Recurse -Filter "nssm.exe" | Select-Object -First 1
        if ($null -eq $nssmExe) {
            Write-Log "NSSM не найден в загруженном архиве. Пропускаем автоматическую регистрацию."
        } else {
            $svcName = "AutopilotService"
            $exePath = Join-Path $venvPath "Scripts\uvicorn.exe"
            $args = "service.main:app --host 127.0.0.1 --port 5000"
            & $nssmExe.FullName install $svcName $exePath $args
            & $nssmExe.FullName set $svcName AppDirectory $installPath
            & $nssmExe.FullName set $svcName Start SERVICE_AUTO_START
            & $nssmExe.FullName start $svcName
            Write-Log "Служба $svcName зарегистрирована и запущена."
        }
    } catch {
        Write-Log "Ошибка при загрузке/установке NSSM: $_. Пропускаем регистрацию службы."
    }
}

Write-Log "Установка завершена. Перезапусти систему или запусти вручную сервис через venv\Scripts\uvicorn.exe service.main:app --host 127.0.0.1 --port 5000"
