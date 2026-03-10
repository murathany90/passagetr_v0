Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$localPropertiesPath = Join-Path $repoRoot "apps\student_app\android\local.properties"

function Get-LocalPropertiesSdkRoot {
  if (-not (Test-Path $localPropertiesPath)) {
    return $null
  }

  $sdkLine = Get-Content -Path $localPropertiesPath |
    Where-Object { $_ -match '^sdk\.dir=' } |
    Select-Object -First 1

  if (-not $sdkLine) {
    return $null
  }

  $sdkPath = $sdkLine.Substring('sdk.dir='.Length).Trim()
  if ([string]::IsNullOrWhiteSpace($sdkPath)) {
    return $null
  }

  $normalized = $sdkPath -replace '\\\\', '\'
  if (Test-Path $normalized) {
    return (Resolve-Path $normalized).Path
  }

  return $null
}

function Resolve-AndroidTool {
  param([string]$ToolRelativePath)

  $candidates = @()

  if ($env:ANDROID_SDK_ROOT) {
    $candidates += Join-Path $env:ANDROID_SDK_ROOT $ToolRelativePath
  }
  if ($env:ANDROID_HOME) {
    $candidates += Join-Path $env:ANDROID_HOME $ToolRelativePath
  }

  $localPropertiesSdkRoot = Get-LocalPropertiesSdkRoot
  if ($localPropertiesSdkRoot) {
    $candidates += Join-Path $localPropertiesSdkRoot $ToolRelativePath
  }

  $localSdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk"
  $candidates += Join-Path $localSdkRoot $ToolRelativePath

  foreach ($candidate in $candidates | Select-Object -Unique) {
    if (Test-Path $candidate) {
      return (Resolve-Path $candidate).Path
    }
  }

  $commandName = [System.IO.Path]::GetFileNameWithoutExtension($ToolRelativePath)
  $command = Get-Command $commandName -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  return $null
}

$adbPath = Resolve-AndroidTool -ToolRelativePath "platform-tools\adb.exe"
$emulatorPath = Resolve-AndroidTool -ToolRelativePath "emulator\emulator.exe"

Write-Host "adb: $adbPath"
Write-Host "emulator: $emulatorPath"

if (-not $adbPath) {
  throw "adb bulunamadi. Android SDK platform-tools yolunu dogrulayin."
}

& $adbPath start-server | Out-Null
$devices = & $adbPath devices
$devices | ForEach-Object { Write-Host $_ }

if (-not $emulatorPath) {
  Write-Warning "emulator bulunamadi. Sadece bagli cihaz listesi dogrulandi."
  exit 0
}

$avds = & $emulatorPath -list-avds
if ($LASTEXITCODE -ne 0) {
  throw "Emulator AVD listesi alinamadi."
}

if ([string]::IsNullOrWhiteSpace(($avds | Out-String))) {
  Write-Warning "Tanimli AVD bulunamadi."
  exit 0
}

Write-Host "AVD listesi:"
$avds | ForEach-Object { Write-Host $_ }
