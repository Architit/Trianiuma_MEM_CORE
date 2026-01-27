
<# 
Lenovo Autopilot Backup & Logs Collector
Version: 2025-09-06
Run as: Administrator (Windows Terminal/PowerShell as Admin)
Purpose: 
  - Full backup of user data, sessions (incl. Telegram Desktop tdata), drivers, installed apps manifest
  - Comprehensive collection of logs (Windows Update, Event Logs, CBS/DISM, WER, Minidumps, Reliability)
  - Health checks (DISM/SFC) with output
  - Creates ZIP with logs ready to send to external system
  - Produces restore helpers for drivers and winget after reset

USAGE:
  1) Right‑click Start → Windows Terminal (Admin).
  2) PowerShell: Set-ExecutionPolicy Bypass -Scope Process -Force
  3) Run: .\lenovo_autopilot_backup.ps1
#>

# --- Guard: Admin rights check ---
$currIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currIdentity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "Please run as Administrator. Right-click Start → Windows Terminal (Admin)."
  exit 1
}

# --- Settings ---
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$base = "C:\APREP_$timestamp"
$dirs = @{
  Root          = $base
  Data          = Join-Path $base "Data"
  Profiles      = Join-Path $base "Data\UserProfiles"
  Telegram      = Join-Path $base "Data\Telegram"
  Browsers      = Join-Path $base "Data\Browsers"
  Drivers       = Join-Path $base "Drivers"
  LogsRoot      = Join-Path $base "Logs"
  LogsEvtx      = Join-Path $base "Logs\EventLogs"
  LogsUpdate    = Join-Path $base "Logs\WindowsUpdate"
  LogsCBS       = Join-Path $base "Logs\CBS"
  LogsDISM      = Join-Path $base "Logs\DISM"
  LogsWER       = Join-Path $base "Logs\WER"
  LogsMini      = Join-Path $base "Logs\Minidump"
  LogsReliab    = Join-Path $base "Logs\Reliability"
  LogsRazer     = Join-Path $base "Logs\Razer"
  System        = Join-Path $base "System"
  Msinfo        = Join-Path $base "System\Msinfo32"
  DxDiag        = Join-Path $base "System\DxDiag"
  Manifests     = Join-Path $base "Manifests"
  Network       = Join-Path $base "System\Network"
  Power         = Join-Path $base "System\Power"
  Lists         = Join-Path $base "System\Lists"
  Scripts       = Join-Path $base "Scripts"
}

$dirs.Values | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

# Start transcript log
$transcriptPath = Join-Path $dirs.Root "APREP-$timestamp.log"
Start-Transcript -Path $transcriptPath -Force | Out-Null

Write-Host "==> Base folder: $($dirs.Root)"

# --- Helper: Safe robocopy (no delete on source) ---
function Copy-Tree {
  param(
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Destination,
    [string[]]$ExcludeDirs = @()
  )
  if (Test-Path $Source) {
    $xd = @()
    foreach ($d in $ExcludeDirs) { $xd += @("/XD", $d) }
    $args = @("$Source", "$Destination", "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/R:1", "/W:1") + $xd
    & robocopy @args | Out-Null
  }
}

# --- 1) Export Drivers ---
try {
  Write-Host "==> Exporting drivers..."
  Export-WindowsDriver -Online -Destination $dirs.Drivers -ErrorAction Stop
} catch {
  Write-Warning "Export-WindowsDriver failed: $($_.Exception.Message)"
}

# --- 2) Event Logs (EVTX) ---
Write-Host "==> Exporting event logs..."
$logList = @(
  "Application","System","Setup","Security",
  "Microsoft-Windows-WindowsUpdateClient/Operational",
  "Microsoft-Windows-DeviceSetupManager/Admin",
  "Microsoft-Windows-AppxPackaging/Operational"
)
foreach ($log in $logList) {
  $safe = ($log -replace '[\\/]', '_')
  $out = Join-Path $dirs.LogsEvtx "$safe.evtx"
  try {
    wevtutil epl "$log" "$out" /ow:true
  } catch {
    Write-Warning "Failed to export $log : $($_.Exception.Message)"
  }
}

# --- 3) Windows Update Logs ---
Write-Host "==> Generating WindowsUpdate.log..."
try {
  $wuLog = Join-Path $dirs.LogsUpdate "WindowsUpdate.log"
  Get-WindowsUpdateLog -LogPath $wuLog
  Copy-Tree -Source "C:\Windows\Logs\WindowsUpdate" -Destination $dirs.LogsUpdate
} catch {
  Write-Warning "Get-WindowsUpdateLog failed: $($_.Exception.Message)"
}

# --- 4) CBS & DISM Logs ---
Write-Host "==> Collecting CBS & DISM logs..."
Copy-Tree -Source "C:\Windows\Logs\CBS" -Destination $dirs.LogsCBS
Copy-Tree -Source "C:\Windows\Logs\DISM" -Destination $dirs.LogsDISM

# --- 5) WER & Minidumps ---
Write-Host "==> Collecting WER & Minidumps..."
Copy-Tree -Source "C:\ProgramData\Microsoft\Windows\WER\ReportArchive" -Destination (Join-Path $dirs.LogsWER "ReportArchive")
Copy-Tree -Source "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"   -Destination (Join-Path $dirs.LogsWER "ReportQueue")
Copy-Tree -Source "C:\Windows\Minidump" -Destination $dirs.LogsMini
if (Test-Path "C:\Windows\MEMORY.DMP") { Copy-Item "C:\Windows\MEMORY.DMP" -Destination $dirs.LogsMini -ErrorAction SilentlyContinue }

# --- 6) Reliability data ---
Write-Host "==> Copying Reliability Monitor data..."
Copy-Tree -Source "C:\ProgramData\Microsoft\RAC\PublishedData" -Destination (Join-Path $dirs.LogsReliab "PublishedData")
Copy-Tree -Source "C:\ProgramData\Microsoft\RAC\StateData"     -Destination (Join-Path $dirs.LogsReliab "StateData")

# --- 7) System reports ---
Write-Host "==> Generating system reports (msinfo32, dxdiag, systeminfo)..."
$msinfo = Join-Path $dirs.Msinfo "system.nfo"
Start-Process "msinfo32.exe" "/nfo `"$msinfo`"" -Wait -NoNewWindow
$dxdiag = Join-Path $dirs.DxDiag "dxdiag.txt"
Start-Process "dxdiag.exe" "/t `"$dxdiag`"" -Wait -NoNewWindow
systeminfo | Out-File -FilePath (Join-Path $dirs.System "systeminfo.txt") -Encoding utf8
driverquery /v | Out-File -FilePath (Join-Path $dirs.System "driverquery.txt") -Encoding utf8

# Devices with problems
Get-PnpDevice | Select-Object Class,FriendlyName,Status,Problem,InstanceId | 
  Export-Csv -Path (Join-Path $dirs.Lists "devices.csv") -NoTypeInformation -Encoding UTF8

# Services & tasks
Get-Service | Select-Object Name,DisplayName,Status,StartType | 
  Export-Csv -Path (Join-Path $dirs.Lists "services.csv") -NoTypeInformation -Encoding UTF8
schtasks /query /fo csv /v > (Join-Path $dirs.Lists "scheduled_tasks.csv")

# Network info (incl. Wi-Fi profiles with keys = sensitive)
Write-Host "==> Exporting network info... (Wi‑Fi keys included)"
ipconfig /all > (Join-Path $dirs.Network "ipconfig_all.txt")
Get-NetIPConfiguration | Format-List * | Out-File (Join-Path $dirs.Network "netipconfig.txt")
try {
  netsh wlan show profiles > (Join-Path $dirs.Network "wlan_profiles.txt")
  netsh wlan export profile key=clear folder="$($dirs.Network)" | Out-Null
} catch { Write-Warning "WLAN export failed: $($_.Exception.Message)" }

# Battery/Power
try { powercfg /batteryreport /output (Join-Path $dirs.Power "battery-report.html") | Out-Null } catch {}
try { powercfg /sleepstudy  /output (Join-Path $dirs.Power "sleepstudy.html") | Out-Null } catch {}

# Windows product key (best-effort)
try {
  $lic = (Get-CimInstance -Query "select * from SoftwareLicensingService")
  $key = $lic.OA3xOriginalProductKey
  if (-not $key) {
    $key = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform").BackupProductKeyDefault
  }
  if ($key) { $key | Out-File (Join-Path $dirs.System "windows_product_key.txt") }
} catch {}

# --- 8) Winget manifest of installed apps ---
Write-Host "==> Exporting installed apps manifest (winget)..."
$wingetJson = Join-Path $dirs.Manifests "installed_apps.json"
try {
  winget export -o "$wingetJson" --include-versions --accept-source-agreements --accept-package-agreements
} catch {
  Write-Warning "winget export failed, falling back to registry scan."
  $regPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )
  $apps = foreach ($p in $regPaths) {
    Get-ItemProperty $p -ErrorAction SilentlyContinue | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
  } | Where-Object { $_.DisplayName } 
  $apps | Export-Csv -Path (Join-Path $dirs.Manifests "installed_apps_fallback.csv") -NoTypeInformation -Encoding UTF8
}

# --- 9) User data backup (Desktop/Documents/Pictures/Videos/Music/Downloads) ---
Write-Host "==> Backing up user libraries..."
$profileRoot = "C:\Users"
$excludeProfiles = @("All Users","Default","Default User","Public","WDAGUtilityAccount")
Get-ChildItem $profileRoot -Directory | Where-Object { $excludeProfiles -notcontains $_.Name } | ForEach-Object {
  $uName = $_.Name
  $dst = Join-Path $dirs.Profiles $uName
  $libs = @("Desktop","Documents","Pictures","Videos","Music","Downloads")
  foreach ($lib in $libs) {
    $src = Join-Path $_.FullName $lib
    $out = Join-Path $dst $lib
    Copy-Tree -Source $src -Destination $out
  }
}

# --- 10) Telegram Desktop sessions (tdata) for all users ---
Write-Host "==> Copying Telegram Desktop tdata for all users..."
Get-ChildItem "C:\Users" -Directory | ForEach-Object {
  $td = Join-Path $_.FullName "AppData\Roaming\Telegram Desktop\tdata"
  if (Test-Path $td) {
    $out = Join-Path $dirs.Telegram "$($_.Name)_tdata"
    Copy-Tree -Source $td -Destination $out
  }
}

# --- 11) Browser profiles (excluding caches) ---
Write-Host "==> Backing up browser profiles (Chrome/Edge/Firefox) — caches excluded."
Get-ChildItem "C:\Users" -Directory | ForEach-Object {
  $u = $_.FullName
  # Chrome
  $chrome = Join-Path $u "AppData\Local\Google\Chrome\User Data"
  if (Test-Path $chrome) {
    $out = Join-Path $dirs.Browsers "$($_.Name)_Chrome"
    Copy-Tree -Source $chrome -Destination $out -ExcludeDirs @("Cache","Code Cache","GPUCache")
  }
  # Edge
  $edge = Join-Path $u "AppData\Local\Microsoft\Edge\User Data"
  if (Test-Path $edge) {
    $out = Join-Path $dirs.Browsers "$($_.Name)_Edge"
    Copy-Tree -Source $edge -Destination $out -ExcludeDirs @("Cache","Code Cache","GPUCache")
  }
  # Firefox
  $ff = Join-Path $u "AppData\Roaming\Mozilla\Firefox\Profiles"
  if (Test-Path $ff) {
    $out = Join-Path $dirs.Browsers "$($_.Name)_Firefox"
    Copy-Tree -Source $ff -Destination $out -ExcludeDirs @("cache2")
  }
}

# --- 12) Vendor-specific logs (Razer, etc) ---
Write-Host "==> Collecting vendor logs (Razer)…"
$razerPaths = @(
  "C:\ProgramData\Razer",
  "$env:ProgramFiles\Razer",
  "$env:ProgramFiles(x86)\Razer"
)
foreach ($p in $razerPaths) {
  if (Test-Path $p) {
    Copy-Tree -Source $p -Destination (Join-Path $dirs.LogsRazer (Split-Path $p -Leaf))
  }
}
# Temp install logs that may include Razer/Synapse attempts
Copy-Tree -Source "$env:LOCALAPPDATA\Temp" -Destination (Join-Path $dirs.LogsRazer "Temp") -ExcludeDirs @()

# --- 13) Health checks (DISM + SFC) ---
Write-Host "==> Running DISM and SFC health checks (this can take a while)…"
$dismLog = Join-Path $dirs.LogsDISM "dism_restorehealth_$timestamp.txt"
$sfcLog  = Join-Path $dirs.LogsCBS  "sfc_scannow_$timestamp.txt"
cmd /c "dism /online /cleanup-image /restorehealth" | Tee-Object -FilePath $dismLog
cmd /c "sfc /scannow" | Tee-Object -FilePath $sfcLog

# --- 14) Create logs ZIP for external system ---
Write-Host "==> Creating AP-LOGS ZIP for external system…"
$logsZip = Join-Path $dirs.Root "AP-LOGS-$timestamp.zip"
try {
  if (Test-Path $logsZip) { Remove-Item $logsZip -Force }
  Compress-Archive -Path $dirs.LogsRoot,$dirs.System,$dirs.Manifests,$dirs.Lists -DestinationPath $logsZip -Force
} catch {
  Write-Warning "Compress-Archive failed for logs: $($_.Exception.Message)"
}

# --- 15) Generate Restore helpers ---
Write-Host "==> Generating restore helpers…"
$restoreCmd = @"
@echo off
echo Installing drivers from Drivers\ (recursive)…
pnputil /add-driver "%~dp0Drivers\*.inf" /subdirs /install
echo Done. Some drivers may require reboot.
pause
"@
$restoreCmdPath = Join-Path $dirs.Scripts "restore_drivers.cmd"
$restoreCmd | Out-File -FilePath $restoreCmdPath -Encoding ASCII -Force

$wingetImportCmd = @"
@echo off
if exist "%~dp0Manifests\installed_apps.json" (
  winget import -i "%~dp0Manifests\installed_apps.json" --accept-source-agreements --accept-package-agreements
) else (
  echo installed_apps.json not found. Use Manifests\installed_apps_fallback.csv manually.
)
pause
"@
$wingetImportPath = Join-Path $dirs.Scripts "restore_apps.cmd"
$wingetImportCmd | Out-File -FilePath $wingetImportPath -Encoding ASCII -Force

$readme = @"
RESTORE GUIDE (Post‑reset)

1) Copy the entire APREP_$timestamp folder to the new system (preferably to C:\APREP_$timestamp).
2) Drivers: Right‑click Scripts\restore_drivers.cmd → Run as Administrator. Reboot if asked.
3) Apps: Right‑click Scripts\restore_apps.cmd → Run. (Requires Microsoft Store / winget working.)
4) Telegram Desktop:
   - Install Telegram Desktop.
   - Close it.
   - Copy folder(s) from Data\Telegram\*_tdata to %APPDATA%\Telegram Desktop\tdata (overwrite).
   - Launch Telegram Desktop → sessions should be restored. (Keep 2FA handy.)
5) User Libraries:
   - Manually copy the needed folders from Data\UserProfiles\<name>\{Desktop,Documents,Pictures,Videos,Music,Downloads}
6) Browsers:
   - Copy profiles from Data\Browsers\* to the same paths under your user (close browsers before copy).
   - Caches were excluded; first launch may take a moment to rebuild.
7) Optional checks:
   - Apply system settings, install any remaining vendor tools.
   - If Windows Update still fails, send AP-LOGS-$timestamp.zip to support/external system.

Security notice: AP-LOGS may contain sensitive info (Wi‑Fi keys, product key fragments, cookies within browser profiles). Share only with trusted parties.
"@
$readmePath = Join-Path $dirs.Root "RESTORE_GUIDE.txt"
$readme | Out-File -FilePath $readmePath -Encoding UTF8 -Force

# --- Final message ---
Stop-Transcript | Out-Null

Write-Host ""
Write-Host "==============================================="
Write-Host " DONE. Base: $($dirs.Root)"
Write-Host " Logs ZIP ready to send: $logsZip"
Write-Host " Restore helpers: $restoreCmdPath  &  $wingetImportPath"
Write-Host " Readme: $readmePath"
Write-Host "==============================================="
