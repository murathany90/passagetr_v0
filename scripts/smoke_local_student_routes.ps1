param(
  [string]$EnvironmentFile = "env/app.web.prod.json",
  [string]$OutputDir = "docs/verification/phase10_production_ui_hardening/local",
  [string]$RunnerRoot = "temp/playwright-local-student-routes",
  [int]$Port = 8170,
  [switch]$SkipBuild,
  [switch]$SkipAnalyze,
  [switch]$SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$buildScript = Join-Path $scriptRoot "build_web_firebase.ps1"
$serveScript = Join-Path $scriptRoot "serve_static_web.ps1"
$smokeScript = Join-Path $scriptRoot "live_smoke_playwright.js"
$buildRoot = Join-Path $repoRoot "build\hosting\student_app"
$resolvedRunnerRoot = Join-Path $repoRoot $RunnerRoot
$resolvedOutputDir = Join-Path $repoRoot $OutputDir

if (-not $SkipBuild) {
  $buildArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", $buildScript,
    "-AppName", "student_app",
    "-EnvironmentFile", $EnvironmentFile
  )
  if ($SkipAnalyze) {
    $buildArgs += "-SkipAnalyze"
  }
  if ($SkipTests) {
    $buildArgs += "-SkipTests"
  }

  & powershell.exe @buildArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Student web build failed."
  }
}

if (-not (Test-Path $buildRoot)) {
  throw "Student hosting build not found: $buildRoot"
}

New-Item -ItemType Directory -Path $resolvedRunnerRoot -Force | Out-Null
New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

if (-not (Test-Path (Join-Path $resolvedRunnerRoot "node_modules\playwright"))) {
  npm install --prefix $resolvedRunnerRoot playwright
  if ($LASTEXITCODE -ne 0) {
    throw "Playwright installation failed."
  }
}

$job = Start-Job -ScriptBlock {
  param($serveScriptPath, $root, $port)
  & powershell -ExecutionPolicy Bypass -File $serveScriptPath -Root $root -Port $port
} -ArgumentList $serveScript, "build/hosting/student_app", $Port

try {
  Start-Sleep -Seconds 3
  $env:NODE_PATH = Join-Path $resolvedRunnerRoot "node_modules"
  node $smokeScript "http://127.0.0.1:$Port" $resolvedOutputDir ""
  if ($LASTEXITCODE -ne 0) {
    throw "Local student route smoke failed."
  }
} finally {
  Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
  Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
}
