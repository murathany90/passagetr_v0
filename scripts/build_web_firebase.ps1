param(
  [ValidateSet("student_app", "admin_console")]
  [string]$AppName = "student_app",
  [string]$EnvironmentFile = "env/app.web.json",
  [switch]$SkipAnalyze,
  [switch]$SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$appRoot = Join-Path $repoRoot "apps\$AppName"
$appBuildRoot = Join-Path $appRoot "build\web"
$hostingBuildRoot = Join-Path $repoRoot "build\web"
$envFilePath = Join-Path $repoRoot $EnvironmentFile

$requiredFiles = @(
  "index.html",
  "main.dart.js",
  "flutter_bootstrap.js",
  "version.json"
)

$blockedFiles = @(
  "db_probe.dart",
  "db_probe.html",
  "db_probe.js",
  "db_probe.js.deps",
  "db_probe.js.map",
  "drift_worker.dart",
  "drift_worker.dart.js",
  "drift_worker.dart.js.deps",
  "drift_worker.dart.js.map",
  "sqlite3.wasm"
)

function Resolve-ToolPath {
  param([string]$ToolName)

  $command = Get-Command $ToolName -ErrorAction SilentlyContinue
  if ($null -eq $command) {
    throw "Required tool not found in PATH: $ToolName"
  }

  return $command.Source
}

function Get-DirectorySizeMb {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return [double]0
  }

  $sum = (Get-ChildItem $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
  if ($null -eq $sum) {
    return [double]0
  }

  return [math]::Round(($sum / 1MB), 2)
}

function Remove-PathIfPresent {
  param([string]$Path)

  if (Test-Path $Path) {
    Remove-Item $Path -Recurse -Force
  }
}

function Invoke-ProductionPrune {
  param([string]$Root)

  $databaseDirectory = Join-Path $Root "assets\assets\db"
  Remove-PathIfPresent -Path $databaseDirectory

  foreach ($relativePath in $blockedFiles) {
    Remove-PathIfPresent -Path (Join-Path $Root $relativePath)
  }
}

function Assert-BuildOutput {
  param([string]$Root)

  foreach ($requiredFile in $requiredFiles) {
    $fullPath = Join-Path $Root $requiredFile
    if (-not (Test-Path $fullPath)) {
      throw "Required web artifact missing: $requiredFile"
    }
  }

  $dbDirectory = Join-Path $Root "assets\assets\db"
  if (Test-Path $dbDirectory) {
    throw "Production web bundle still contains local db assets: $dbDirectory"
  }

  foreach ($relativePath in $blockedFiles) {
    $fullPath = Join-Path $Root $relativePath
    if (Test-Path $fullPath) {
      throw "Production web bundle still contains blocked artifact: $relativePath"
    }
  }
}

function Copy-BuildToHostingRoot {
  param(
    [string]$SourceRoot,
    [string]$DestinationRoot
  )

  Remove-PathIfPresent -Path $DestinationRoot
  New-Item -ItemType Directory -Path $DestinationRoot | Out-Null
  Copy-Item -Path (Join-Path $SourceRoot "*") -Destination $DestinationRoot -Recurse -Force
}

if (-not (Test-Path $appRoot)) {
  throw "Application path not found: $appRoot"
}

if (-not (Test-Path $envFilePath)) {
  throw "Environment file not found: $EnvironmentFile"
}

$flutter = Resolve-ToolPath -ToolName "flutter"

Push-Location $repoRoot
try {
  if (-not $SkipAnalyze) {
    Write-Host "Running flutter analyze..."
    & $flutter analyze
  }

  if (-not $SkipTests) {
    Write-Host "Running app tests for $AppName..."
    & $flutter test "apps/$AppName"
  }

  Write-Host "Building production web bundle for $AppName..."
  Push-Location $appRoot
  try {
    & $flutter build web --release "--dart-define-from-file=$envFilePath"
  } finally {
    Pop-Location
  }

  $sizeBeforePruneMb = Get-DirectorySizeMb -Path $appBuildRoot
  Write-Host "App build size before prune: $sizeBeforePruneMb MB"

  Invoke-ProductionPrune -Root $appBuildRoot
  Assert-BuildOutput -Root $appBuildRoot

  Copy-BuildToHostingRoot -SourceRoot $appBuildRoot -DestinationRoot $hostingBuildRoot
  Assert-BuildOutput -Root $hostingBuildRoot

  $sizeAfterPruneMb = Get-DirectorySizeMb -Path $hostingBuildRoot
  Write-Host "Hosting bundle size after prune: $sizeAfterPruneMb MB"
  Write-Host "Firebase web bundle is ready at $hostingBuildRoot"
} finally {
  Pop-Location
}
