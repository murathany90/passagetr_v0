param(
  [string]$EnvironmentFile = "env/app.web.json",
  [switch]$SkipRlsSmoke
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$envFilePath = Join-Path $repoRoot $EnvironmentFile

if (-not (Test-Path $envFilePath)) {
  throw "Environment file not found: $envFilePath"
}

$qualityGateArgs = @(
  "-EnvironmentFile",
  $EnvironmentFile
)
if ($SkipRlsSmoke) {
  $qualityGateArgs += "-SkipRlsSmoke"
}

& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "quality_gate.ps1") @qualityGateArgs
if ($LASTEXITCODE -ne 0) {
  throw "Quality gate failed."
}

& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "check_firebase_hosting_ready.ps1") `
  -AppName "student_app" `
  -EnvironmentFile $EnvironmentFile
if ($LASTEXITCODE -ne 0) {
  throw "Student Firebase hosting readiness failed."
}

& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "check_firebase_hosting_ready.ps1") `
  -AppName "admin_console" `
  -EnvironmentFile $EnvironmentFile
if ($LASTEXITCODE -ne 0) {
  throw "Admin Firebase hosting readiness failed."
}

& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "smoke_web_auth.ps1") `
  -AppName "student_app" `
  -EnvironmentFile $EnvironmentFile `
  -SkipAnalyze `
  -SkipTests
if ($LASTEXITCODE -ne 0) {
  throw "Student auth smoke failed."
}

& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "smoke_web_responsive.ps1") `
  -AppName "student_app" `
  -EnvironmentFile $EnvironmentFile `
  -OutputDir "artifacts/release_preflight/student_web"
if ($LASTEXITCODE -ne 0) {
  throw "Student responsive smoke failed."
}

& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "smoke_web_responsive.ps1") `
  -AppName "admin_console" `
  -EnvironmentFile $EnvironmentFile `
  -OutputDir "artifacts/release_preflight/admin_web"
if ($LASTEXITCODE -ne 0) {
  throw "Admin responsive smoke failed."
}

Push-Location $repoRoot
try {
  & powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "build_android_release.ps1") `
    -AppName "student_app" `
    -EnvironmentFile $EnvironmentFile
  if ($LASTEXITCODE -ne 0) {
    throw "Android release build failed."
  }
} finally {
  Pop-Location
}

Write-Host "Release preflight passed."
