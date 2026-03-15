param(
  [string]$EnvironmentFile = "env/app.web.prod.json",
  [ValidateSet("student_app")]
  [string]$AppName = "student_app"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$envFilePath = Join-Path $repoRoot $EnvironmentFile
$appRoot = Join-Path $repoRoot "apps\$AppName"
$artifactPath = Join-Path $appRoot "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
$pubspecPath = Join-Path $appRoot "pubspec.yaml"

function Resolve-ToolPath {
  param([string]$ToolName)

  $command = Get-Command $ToolName -ErrorAction SilentlyContinue
  if ($null -eq $command) {
    throw "Required tool not found in PATH: $ToolName"
  }

  return $command.Source
}

function Get-RequiredJsonValue {
  param(
    [object]$Config,
    [string]$Key
  )

  $value = $Config.$Key
  if ($null -eq $value) {
    throw "Environment file is missing required key: $Key"
  }

  $normalized = $value.ToString().Trim()
  if ([string]::IsNullOrWhiteSpace($normalized)) {
    throw "Environment file contains an empty required key: $Key"
  }

  return $normalized
}

function Get-VersionNameFromPubspec {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    throw "pubspec.yaml not found: $Path"
  }

  $match = Select-String -Path $Path -Pattern '^version:\s*([^+\s]+)'
  if ($null -eq $match) {
    throw "Unable to read app version from pubspec.yaml"
  }

  return $match.Matches[0].Groups[1].Value.Trim()
}

if (-not (Test-Path $envFilePath)) {
  throw "Environment file not found: $envFilePath"
}

if (-not (Test-Path $appRoot)) {
  throw "Application path not found: $appRoot"
}

try {
  $envConfig = Get-Content $envFilePath -Raw | ConvertFrom-Json
} catch {
  throw "Environment file is not valid JSON: $envFilePath"
}

[void](Get-RequiredJsonValue -Config $envConfig -Key "SUPABASE_URL")
[void](Get-RequiredJsonValue -Config $envConfig -Key "SUPABASE_ANON_KEY")

$flutterWrapper = Resolve-ToolPath -ToolName "flutter"
$flutterBinRoot = Split-Path -Parent $flutterWrapper
$flutterSdkRoot = Split-Path -Parent $flutterBinRoot
$dart = Join-Path $flutterSdkRoot "bin\cache\dart-sdk\bin\dart.exe"
$snapshot = Join-Path $flutterSdkRoot "bin\cache\flutter_tools.snapshot"

if (-not (Test-Path $dart)) {
  throw "Dart executable not found: $dart"
}

if (-not (Test-Path $snapshot)) {
  throw "Flutter tool snapshot not found: $snapshot"
}

Push-Location $appRoot
try {
  & $dart $snapshot --suppress-analytics build apk `
    --release `
    --no-pub `
    "--dart-define-from-file=$envFilePath" `
    --target-platform android-arm64 `
    --split-per-abi

  if ($LASTEXITCODE -ne 0) {
    throw "Android release build failed."
  }
} finally {
  Pop-Location
}

if (-not (Test-Path $artifactPath)) {
  throw "Expected APK artifact was not produced: $artifactPath"
}

$artifact = Get-Item $artifactPath
$hash = (Get-FileHash -Path $artifact.FullName -Algorithm SHA1).Hash.ToLowerInvariant()
$hashPath = "$($artifact.FullName).sha1"
[System.IO.File]::WriteAllText($hashPath, $hash)

$versionName = Get-VersionNameFromPubspec -Path $pubspecPath
$versionedArtifactPath = Join-Path $artifact.DirectoryName ("passagetr-student-v{0}-arm64-prod.apk" -f $versionName)
Copy-Item -Path $artifact.FullName -Destination $versionedArtifactPath -Force

Write-Host "Android release APK is ready:"
Write-Host "  APK: $($artifact.FullName)"
Write-Host "  Versioned APK: $versionedArtifactPath"
Write-Host "  Size: $([math]::Round($artifact.Length / 1MB, 2)) MB"
Write-Host "  SHA1: $hash"
