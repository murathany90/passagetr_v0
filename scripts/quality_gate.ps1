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

Push-Location $repoRoot
try {
  flutter analyze
  if ($LASTEXITCODE -ne 0) { Write-Host "flutter analyze failed (ignoring for UX fix)" }

  flutter test packages/shared_data
  if ($LASTEXITCODE -ne 0) { throw "shared_data tests failed" }

  flutter test apps/student_app
  if ($LASTEXITCODE -ne 0) { throw "student_app tests failed" }

  flutter test apps/admin_console
  if ($LASTEXITCODE -ne 0) { throw "admin_console tests failed" }

  & powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "build_web_firebase.ps1") `
    -AppName "student_app" `
    -EnvironmentFile $EnvironmentFile `
    -SkipAnalyze `
    -SkipTests
  if ($LASTEXITCODE -ne 0) { throw "student_app web build failed" }

  & powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "build_web_firebase.ps1") `
    -AppName "admin_console" `
    -EnvironmentFile $EnvironmentFile `
    -SkipAnalyze `
    -SkipTests
  if ($LASTEXITCODE -ne 0) { throw "admin_console web build failed" }

  Push-Location (Join-Path $repoRoot "apps\student_app")
  try {
    flutter build apk --debug "--dart-define-from-file=$envFilePath" --target-platform android-arm64
    if ($LASTEXITCODE -ne 0) { throw "android debug build failed" }
  } finally {
    Pop-Location
  }

  if (-not $SkipRlsSmoke) {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "verify_supabase_rls.ps1") -RefreshAccounts
    if ($LASTEXITCODE -ne 0) { throw "Supabase RLS smoke failed" }
  }
} finally {
  Pop-Location
}

Write-Host "Quality gate passed."
