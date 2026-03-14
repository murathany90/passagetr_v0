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
$symbolsRoot = Join-Path $appRoot "build\app\outputs\symbols"
$artifactPath = Join-Path $appRoot "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"

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

$flutter = Resolve-ToolPath -ToolName "flutter"

Push-Location $appRoot
try {
  if (-not (Test-Path $symbolsRoot)) {
    New-Item -ItemType Directory -Path $symbolsRoot -Force | Out-Null
  }

  & $flutter build apk `
    --release `
    "--dart-define-from-file=$envFilePath" `
    --target-platform android-arm64 `
    --split-per-abi `
    --obfuscate `
    "--split-debug-info=$symbolsRoot"

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

Write-Host "Android release APK is ready:"
Write-Host "  APK: $($artifact.FullName)"
Write-Host "  Size: $([math]::Round($artifact.Length / 1MB, 2)) MB"
Write-Host "  SHA1: $hash"
