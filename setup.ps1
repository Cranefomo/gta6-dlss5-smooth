<#
gta6-dlss5-smooth setup  (github.com/Cranefomo/gta6-dlss5-smooth)

Installs Veyra (github.com/Likely7/Veyra-NRVideo, GPL-3.0) from its official GitHub release,
checks the SHA-256 hash, and prints the preset for YOUR graphics card and screen.

one line:   irm https://raw.githubusercontent.com/Cranefomo/gta6-dlss5-smooth/main/setup.ps1 | iex
from file:  powershell -ExecutionPolicy Bypass -File setup.ps1 [-CheckOnly] [-Yes] [-Uninstall] [-InstallDir D:\Veyra]

What it never does: ask for admin, touch antivirus or system settings, download from any site except github.com.
#>
param(
  [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Veyra'),
  [switch]$CheckOnly,   # only check GPU + screen and print your preset
  [switch]$Yes,         # skip the confirm question
  [switch]$Uninstall,   # remove what this script installed
  [string]$ZipPath,     # use a zip you already downloaded (still hash-checked)
  [string]$SumsPath,    # local SHA256SUMS.txt for offline -ZipPath
  [string]$GpuName,     # manual override if detection is wrong
  [int]$Hz = 0          # manual override for screen refresh rate
)
$ErrorActionPreference = 'Stop'
$Repo = 'Likely7/Veyra-NRVideo'
$UA = @{ 'User-Agent' = 'gta6-dlss5-smooth' }

function Say($k, $v, $c = 'Gray') { Write-Host ('  {0,-16}' -f $k) -NoNewline -ForegroundColor DarkGray; Write-Host $v -ForegroundColor $c }
function Shortcut { $d = [Environment]::GetFolderPath('Desktop'); if (-not $d) { $d = $HOME }; Join-Path $d 'Veyra.lnk' }

Write-Host ''
Write-Host '  gta6-dlss5-smooth' -ForegroundColor Cyan
Write-Host '  installs official Veyra, checks the hash, picks your preset' -ForegroundColor DarkGray
Write-Host ''

# ---------- uninstall ----------
if ($Uninstall) {
  $lnk = Shortcut
  Say 'remove' $InstallDir
  Say 'remove' $lnk
  if (-not $Yes -and (Read-Host '  continue? [y/N]') -notmatch '^[yY]') { Say 'stopped' 'nothing removed' Yellow; return }
  if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
  if (Test-Path $lnk) { Remove-Item $lnk -Force }
  Say 'done' 'Veyra removed' Green; return
}

# ---------- 1. system ----------
$isWin = [Environment]::OSVersion.Platform -eq 'Win32NT'
$build = if ($isWin) { [Environment]::OSVersion.Version.Build } else { 0 }
if (-not $GpuName) {
  if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) { $GpuName = (& nvidia-smi --query-gpu=name --format=csv,noheader | Select-Object -First 1).Trim() }
  elseif ($isWin) { $GpuName = (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA|AMD|Radeon' } | Select-Object -First 1).Name }
}
if ($Hz -le 0 -and $isWin) {
  $Hz = (Get-CimInstance Win32_VideoController | Where-Object { $_.CurrentRefreshRate } | Measure-Object CurrentRefreshRate -Maximum).Maximum
}
if (-not $GpuName) { $GpuName = 'unknown' }
if (-not $Hz) { $Hz = 60 }

Say 'windows' ($(if ($build -ge 22000) { "11 (build $build)" } elseif ($isWin) { "build $build (Veyra wants Windows 11)" } else { 'not Windows' })) ($(if ($build -ge 22000) { 'Green' } else { 'Yellow' }))
Say 'gpu' $GpuName
Say 'screen' "$Hz Hz"

# ---------- 2. your preset ----------
$tier = switch -Regex ($GpuName) {
  'RTX\s*50\d\d' { 'RTX50'; break } 'RTX\s*40\d\d' { 'RTX40'; break } 'RTX\s*30\d\d' { 'RTX30'; break }
  'RTX\s*20\d\d' { 'RTX20'; break } 'RX\s*(7|9)\d\d\d' { 'AMD'; break } default { 'NONE' } }
$fast = $Hz -ge 120
$fg = switch ($tier) {
  'RTX50' { if ($fast) { 'DLSS Frame Generation 4X' } else { 'DLSS Frame Generation 2X' } }
  'RTX40' { if ($fast) { '4X' } else { '2X' } }
  'RTX30' { '2X compatibility mode' } 'RTX20' { 'off' } 'AMD' { 'AMD frame generation 2X' } default { '' } }
$preset = switch ($tier) {
  'RTX50' { [ordered]@{ 'NR enhancement' = 'on, RTX 50, NVIDIA original, 2 layers'; 'stabilizer' = 'on'; 'super res' = "RTX Video SR, target = your screen"; 'frame gen' = $fg } }
  'RTX40' { [ordered]@{ 'NR enhancement' = 'on, RTX 20-50, SF, 1 layer'; 'stabilizer' = 'on'; 'super res' = 'RTX Video SR, target = your screen'; 'frame gen' = $fg } }
  'RTX30' { [ordered]@{ 'NR enhancement' = 'on, RTX 20-50, SF, 1 layer'; 'super res' = 'RTX Video SR'; 'frame gen' = $fg } }
  'RTX20' { [ordered]@{ 'NR enhancement' = 'on, RTX 20-50, SF, 1 layer'; 'super res' = 'RTX Video SR'; 'frame gen' = $fg } }
  'AMD'   { [ordered]@{ 'NR enhancement' = 'AMD NR (experimental)'; 'frame gen' = $fg } }
  default { $null } }

Write-Host ''
if (-not $preset) {
  Say 'result' 'no supported card found. Veyra needs GeForce RTX 20-50 or Radeon RX 7000/9000.' Yellow
  Say 'tip' 'wrong card? run again with -GpuName "RTX 4070"' DarkGray
  return
}
Write-Host "  YOUR PRESET  ($tier, $Hz Hz)" -ForegroundColor Cyan
foreach ($k in $preset.Keys) { Say $k $preset[$k] White }
if (-not $fast -and $tier -in 'RTX50', 'RTX40') { Say 'note' 'a 120 Hz+ screen unlocks 4X frame gen' DarkGray }
Write-Host ''
if ($CheckOnly) { Say 'check only' 'nothing downloaded' Green; return }
if ($tier -eq 'RTX20' -or $build -lt 22000) { Say 'warning' 'your setup is at the edge of what Veyra supports' Yellow }

# ---------- 3. find the official release ----------
$flavor = if ($tier -eq 'AMD') { 'AMD' } else { 'NVIDIA' }
$pattern = "^Veyra-[\d.]+-$flavor-win64-portable\.zip$"
if ($ZipPath) {
  $zip = (Resolve-Path $ZipPath).Path; $name = Split-Path $zip -Leaf
  if ($name -notmatch $pattern) { throw "zip name '$name' does not look like an official $flavor build" }
  if (-not $SumsPath) { throw 'offline -ZipPath needs -SumsPath (SHA256SUMS.txt from the same release)' }
  $sums = Get-Content $SumsPath -Raw; $digest = $null; $tag = 'local'
} else {
  $rel = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -Headers $UA
  $asset = $rel.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
  $sumA = $rel.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' } | Select-Object -First 1
  if (-not $asset -or -not $sumA) { throw "no $flavor portable zip or SHA256SUMS.txt in $($rel.tag_name)" }
  $name = $asset.name; $tag = $rel.tag_name
  $digest = if ($asset.digest) { ($asset.digest -replace '^sha256:', '').ToLower() } else { $null }
  $zip = Join-Path $InstallDir $name
}

# ---------- 4. show the plan, ask ----------
Write-Host '  PLAN' -ForegroundColor Cyan
Say 'from' "github.com/$Repo (release $tag)"
Say 'file' ($(if ($asset) { '{0}, {1} MB' -f $name, [math]::Round($asset.size / 1MB) } else { $name }))
Say 'to' $InstallDir
Say 'shortcut' (Shortcut)
Say 'admin' 'not needed'
if (-not $Yes -and (Read-Host '  install? [Y/n]') -match '^[nN]') { Say 'stopped' 'nothing downloaded' Yellow; return }

# ---------- 5. download + hash ----------
New-Item -ItemType Directory -Force $InstallDir | Out-Null
if (-not $ZipPath) {
  Say 'download' $name
  if (Get-Command curl.exe -ErrorAction SilentlyContinue) { & curl.exe -L --retry 3 -# -o $zip $asset.browser_download_url; if ($LASTEXITCODE) { throw 'download failed' } }
  else { Invoke-WebRequest $asset.browser_download_url -OutFile $zip -Headers $UA }
  $sums = Invoke-RestMethod $sumA.browser_download_url -Headers $UA
}
$want = ($sums -split "`n" | Where-Object { $_ -match [regex]::Escape($name) } | ForEach-Object { ($_.Trim() -split '\s+')[0].ToLower() }) | Select-Object -First 1
$have = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
if (-not $want -or $have -ne $want -or ($digest -and $have -ne $digest)) {
  if (-not $ZipPath) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
  throw "SHA-256 MISMATCH for $name. Stopped, nothing installed."
}
Say 'sha-256' ("{0}...  matches release" -f $have.Substring(0, 16)) Green

# ---------- 6. unpack, shortcut, save preset ----------
Expand-Archive $zip $InstallDir -Force
$exe = Get-ChildItem $InstallDir -Recurse -Filter 'veyra_qml_ui.exe' | Select-Object -First 1
if (-not $exe) { throw 'veyra_qml_ui.exe not found in the zip' }
if ($isWin) {
  $s = (New-Object -ComObject WScript.Shell).CreateShortcut((Shortcut))
  $s.TargetPath = $exe.FullName; $s.WorkingDirectory = $exe.DirectoryName; $s.Save()
}
$txt = @("gta6-dlss5-smooth preset for $GpuName, $Hz Hz", '') + ($preset.Keys | ForEach-Object { "{0,-16}{1}" -f $_, $preset[$_] }) +
  @('', 'check any clip for real FPS: https://cranefomo.github.io/realfps', 'Veyra: https://github.com/Likely7/Veyra-NRVideo (GPL-3.0)')
$txt | Set-Content (Join-Path $exe.DirectoryName 'MY-PRESET.txt') -Encoding UTF8
if (-not $ZipPath) { Remove-Item $zip -Force }

Say 'installed' $exe.FullName Green
Say 'preset' (Join-Path $exe.DirectoryName 'MY-PRESET.txt') Green
Write-Host ''
Write-Host '  open Veyra from the desktop shortcut and copy the preset above.' -ForegroundColor White
Write-Host '  remove later:  setup.ps1 -Uninstall' -ForegroundColor DarkGray
Write-Host ''
