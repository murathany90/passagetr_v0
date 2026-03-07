param(
  [string]$EnvironmentFile = "env/app.web.prod.json",
  [switch]$SkipAnalyze,
  [switch]$SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$buildRoot = Join-Path $repoRoot "build\\web"
$envFilePath = Join-Path $repoRoot $EnvironmentFile

$testTargets = @(
  "test\\state\\content_hydration_provider_test.dart",
  "test\\features\\shell\\main_shell_page_test.dart",
  "test\\features\\home\\home_dashboard_page_test.dart",
  "test\\features\\profile\\profile_page_test.dart",
  "test\\features\\words\\word_home_page_test.dart",
  "test\\features\\words\\word_level_hub_page_test.dart",
  "test\\features\\readings\\reading_home_page_test.dart",
  "test\\features\\readings\\reading_detail_page_test.dart",
  "test\\features\\grammar\\grammar_home_page_test.dart",
  "test\\features\\grammar\\grammar_reader_page_test.dart"
)

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

  $databaseDirectory = Join-Path $Root "assets\\assets\\db"
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

  $dbDirectory = Join-Path $Root "assets\\assets\\db"
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
    Write-Host "Running targeted widget tests..."
    & $flutter test @testTargets
  }

  Write-Host "Building production web bundle..."
  & $flutter build web --release "--dart-define-from-file=$envFilePath"

  $sizeBeforePruneMb = Get-DirectorySizeMb -Path $buildRoot
  Write-Host "Build size before prune: $sizeBeforePruneMb MB"

  Invoke-ProductionPrune -Root $buildRoot
  Assert-BuildOutput -Root $buildRoot

  $sizeAfterPruneMb = Get-DirectorySizeMb -Path $buildRoot
  Write-Host "Build size after prune: $sizeAfterPruneMb MB"
  Write-Host "Firebase web bundle is ready at $buildRoot"
} finally {
  Pop-Location
}
