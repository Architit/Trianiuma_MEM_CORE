
<# 
Post‑Reset Optimize · Safe Preset
Run as: Administrator
What it does (idempotent):
  • Creates a restore point (if System Protection is on).
  • Enables .NET 3.5 (common dependency).
  • Sets power plan to High performance; extends sleep timeouts.
  • Disables consumer bloat/suggestions & basic telemetry hardening.
  • Turns off some nonessential Xbox services (kept Manual, not Disabled).
  • Debloats common preinstalled apps (Clipchamp/Xbox/News/Weather/etc.).
  • Produces a report of changes at C:\APREP_*\System\OptimizeReport.txt if the folder exists, otherwise %TEMP%.
#>

# --- Guard: Admin ---
$currIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currIdentity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "Run as Administrator."
  exit 1
}

# --- Paths ---
$ts = Get-Date -Format "yyyyMMdd-HHmm"
$aprep = Get-ChildItem "C:\APREP_*" -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$reportDir = if ($aprep) { Join-Path $aprep.FullName "System" } else { $env:TEMP }
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$report = Join-Path $reportDir "OptimizeReport_$ts.txt"

function Log($msg){ $msg | Tee-Object -FilePath $report -Append }

Log "== Post‑Reset Optimize started $ts =="

# --- Restore point ---
try {
  Checkpoint-Computer -Description "Post-Reset Optimize $ts" -RestorePointType "MODIFY_SETTINGS"
  Log "Restore point created."
} catch { Log "Restore point failed: $($_.Exception.Message)" }

# --- Enable .NET 3.5 ---
try {
  Log "Enabling .NET Framework 3.5…"
  DISM /Online /Enable-Feature /FeatureName:NetFX3 /All | Out-Null
  Log ".NET 3.5 enabled."
} catch { Log ".NET 3.5 failed: $($_.Exception.Message)" }

# --- Power plan & timeouts ---
try {
  Log "Setting High performance power plan…"
  powercfg /SETACTIVE SCHEME_MIN | Out-Null
  # AC timeouts: display off 30min, sleep 0 (never)
  powercfg /X -monitor-timeout-ac 30 | Out-Null
  powercfg /X -standby-timeout-ac 0 | Out-Null
  # DC (battery): display 10min, sleep 30min
  powercfg /X -monitor-timeout-dc 10 | Out-Null
  powercfg /X -standby-timeout-dc 30 | Out-Null
  Log "Power plan adjusted."
} catch { Log "Power plan failed: $($_.Exception.Message)" }

# --- Policies: disable Windows consumer features ---
try {
  Log "Applying policy: Disable Windows Consumer Features…"
  New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
  New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -PropertyType DWord -Value 1 -Force | Out-Null
  Log "Consumer features disabled."
} catch { Log "Policy set failed: $($_.Exception.Message)" }

# --- Suggestions/ads/tips (per-user defaults) ---
try {
  Log "Hardening ContentDeliveryManager suggestions…"
  $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
  New-Item -Path $cdm -Force | Out-Null
  $flags = @(
    "SilentInstalledAppsEnabled",
    "SubscribedContent-314559Enabled",
    "SubscribedContent-338388Enabled",
    "SubscribedContent-338389Enabled",
    "SubscribedContent-338393Enabled",
    "SubscribedContent-353694Enabled",
    "SubscribedContent-353696Enabled",
    "SystemPaneSuggestionsEnabled"
  )
  foreach($f in $flags){
    New-ItemProperty -Path $cdm -Name $f -PropertyType DWord -Value 0 -Force | Out-Null
  }
  Log "Suggestions off for current user."
} catch { Log "CDM tweaks failed: $($_.Exception.Message)" }

# --- Telemetry to Basic (1) ---
try {
  Log "Setting telemetry to Basic (1)…"
  New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force | Out-Null
  New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -PropertyType DWord -Value 1 -Force | Out-Null
  Log "Telemetry policy set."
} catch { Log "Telemetry policy failed: $($_.Exception.Message)" }

# --- Xbox services to Manual (safe) ---
$svcList = @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc")
foreach($svc in $svcList){
  try {
    Set-Service -Name $svc -StartupType Manual -ErrorAction Stop
    Log "Service $svc set to Manual."
  } catch { Log "Service $svc change failed: $($_.Exception.Message)" }
}

# --- Debloat preinstalled apps (safe list) ---
$removeAppx = @(
  "Microsoft.XboxApp",
  "Microsoft.Xbox.TCUI",
  "Microsoft.XboxSpeechToTextOverlay",
  "Microsoft.XboxGameOverlay",
  "Microsoft.XboxGamingOverlay",
  "Microsoft.GamingApp",
  "Microsoft.ZuneMusic",
  "Microsoft.ZuneVideo",
  "Microsoft.BingNews",
  "Microsoft.BingWeather",
  "Microsoft.GetHelp",
  "Microsoft.Getstarted",
  "Microsoft.People",
  "Microsoft.SkypeApp",
  "Microsoft.MicrosoftOfficeHub",
  "Microsoft.MicrosoftSolitaireCollection",
  "Microsoft.YourPhone",
  "Clipchamp.Clipchamp"
)
Log "Removing provisioned Appx packages (for new users)…"
foreach($pkg in $removeAppx){
  try { Remove-AppxProvisionedPackage -Online -PackageName $pkg -AllUsers | Out-Null } catch {}
}
Log "Removing Appx packages for current/all users…"
foreach($pkg in $removeAppx){
  try { Get-AppxPackage -AllUsers -Name $pkg | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue } catch {}
}

# --- Winget uninstall (optional) ---
$wingetList = @(
  "Microsoft.549981C3F5F10",   # Cortana legacy
  "Spotify.Spotify",
  "Bytedance.PICOXR",          # OEM VR bloat (if present)
  "ByteDance.CapCut",
  "TikTok.TikTok",
  "Facebook.Facebook",
  "WhatsApp.WhatsApp",
  "Disney.DisneyPlus"
)
foreach($p in $wingetList){
  try { winget uninstall --id $p --silent --accept-source-agreements --accept-package-agreements } catch {}
}

Log "== Optimize finished =="
Write-Host "Optimization complete. Report: $report"
