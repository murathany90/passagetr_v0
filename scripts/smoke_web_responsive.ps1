param(
  [ValidateSet("student_app", "admin_console")]
  [string]$AppName = "student_app",
  [string]$EnvironmentFile = "env/app.web.json",
  [string]$OutputDir = "artifacts/responsive_smoke",
  [int]$Port = 8160,
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$appRoot = Join-Path $repoRoot "apps\$AppName"
$hostingBuildRoot = Join-Path $repoRoot "build\hosting\$AppName"
$envFilePath = Join-Path $repoRoot $EnvironmentFile
$serveScript = Join-Path $scriptRoot "serve_static_web.ps1"
$smokeScript = Join-Path $scriptRoot "local_responsive_smoke_playwright.js"
$runnerRoot = Join-Path $repoRoot "temp\playwright-responsive-smoke"

if (-not (Test-Path $appRoot)) {
  throw "Application path not found: $appRoot"
}

if (-not (Test-Path $envFilePath)) {
  throw "Environment file not found: $envFilePath"
}

if (-not (Test-Path $serveScript)) {
  throw "Static server script not found: $serveScript"
}

if (-not (Test-Path $smokeScript)) {
  throw "Responsive smoke script not found: $smokeScript"
}

if (-not $SkipBuild) {
  & powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "build_web_firebase.ps1") `
    -AppName $AppName `
    -EnvironmentFile $EnvironmentFile `
    -SkipAnalyze `
    -SkipTests
  if ($LASTEXITCODE -ne 0) {
    throw "Web build failed for $AppName"
  }
}

$job = Start-Job -ScriptBlock {
  param($serveScriptPath, $root, $port)
  & powershell -ExecutionPolicy Bypass -File $serveScriptPath -Root $root -Port $port
} -ArgumentList $serveScript, "build/hosting/$AppName", $Port

try {
  New-Item -ItemType Directory -Path $runnerRoot -Force | Out-Null
  if (-not (Test-Path (Join-Path $runnerRoot "node_modules\playwright"))) {
    npm install --prefix $runnerRoot playwright
  }

  Start-Sleep -Seconds 3
  $env:NODE_PATH = Join-Path $runnerRoot "node_modules"
  node $smokeScript "http://127.0.0.1:$Port" $AppName $OutputDir
  if ($LASTEXITCODE -ne 0) {
    throw "Responsive smoke failed for $AppName"
  }
} finally {
  Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
  Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
}
