param(
  [string]$StudentUrl = "https://passagetr-fef48.web.app",
  [string]$AdminUrl = "https://passagetr-admin.web.app",
  [string]$OutputDir = "docs/verification/phase10_production_ui_hardening/live",
  [string]$RunnerRoot = "temp/playwright-live-ui"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$smokeScript = Join-Path $scriptRoot "live_smoke_playwright.js"
$resolvedRunnerRoot = Join-Path $repoRoot $RunnerRoot
$resolvedOutputDir = Join-Path $repoRoot $OutputDir

if (-not (Test-Path $smokeScript)) {
  throw "Live smoke script not found: $smokeScript"
}

New-Item -ItemType Directory -Path $resolvedRunnerRoot -Force | Out-Null
New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

if (-not (Test-Path (Join-Path $resolvedRunnerRoot "node_modules\playwright"))) {
  npm install --prefix $resolvedRunnerRoot playwright
  if ($LASTEXITCODE -ne 0) {
    throw "Playwright installation failed."
  }
}

$env:NODE_PATH = Join-Path $resolvedRunnerRoot "node_modules"
node $smokeScript $StudentUrl $resolvedOutputDir $AdminUrl
if ($LASTEXITCODE -ne 0) {
  throw "Live UI smoke failed."
}
