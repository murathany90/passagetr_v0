param(
  [string]$EnvironmentFile = "env/app.web.prod.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$envFilePath = Join-Path $repoRoot $EnvironmentFile
$firebasercPath = Join-Path $repoRoot ".firebaserc"
$firebaseJsonPath = Join-Path $repoRoot "firebase.json"
$buildScriptPath = Join-Path $scriptRoot "build_web_firebase.ps1"
$deployScriptPath = Join-Path $scriptRoot "deploy_web_firebase.ps1"

$errors = [System.Collections.Generic.List[string]]::new()

function Add-CheckResult {
  param(
    [string]$Label,
    [bool]$Success,
    [string]$Detail
  )

  $status = if ($Success) { "[OK]" } else { "[!!]" }
  Write-Host "$status $Label - $Detail"
}

function Resolve-ToolPath {
  param([string]$ToolName)

  $command = Get-Command $ToolName -ErrorAction SilentlyContinue
  if ($null -eq $command) {
    return $null
  }

  return $command.Source
}

$firebasePath = Resolve-ToolPath -ToolName "firebase"
if ($null -eq $firebasePath) {
  $errors.Add("Firebase CLI is not installed.")
  Add-CheckResult -Label "Firebase CLI" -Success $false -Detail "Install with npm install -g firebase-tools"
} else {
  Add-CheckResult -Label "Firebase CLI" -Success $true -Detail $firebasePath
}

if (-not (Test-Path $firebaseJsonPath)) {
  $errors.Add("firebase.json is missing.")
  Add-CheckResult -Label "firebase.json" -Success $false -Detail "Missing"
} else {
  Add-CheckResult -Label "firebase.json" -Success $true -Detail "Found"
}

if (-not (Test-Path $firebasercPath)) {
  $errors.Add(".firebaserc is missing.")
  Add-CheckResult -Label ".firebaserc" -Success $false -Detail "Missing"
} else {
  $firebasercContent = Get-Content $firebasercPath -Raw
  if ($firebasercContent -match "replace-with-your-firebase-project-id") {
    $errors.Add(".firebaserc still contains the placeholder Firebase project id.")
    Add-CheckResult -Label ".firebaserc" -Success $false -Detail "Replace the placeholder project id"
  } else {
    Add-CheckResult -Label ".firebaserc" -Success $true -Detail "Project id configured"
  }
}

if (-not (Test-Path $envFilePath)) {
  $errors.Add("Environment file is missing: $EnvironmentFile")
  Add-CheckResult -Label "Environment file" -Success $false -Detail $EnvironmentFile
} else {
  Add-CheckResult -Label "Environment file" -Success $true -Detail $EnvironmentFile
}

if (-not (Test-Path $buildScriptPath)) {
  $errors.Add("Build script is missing.")
  Add-CheckResult -Label "build_web_firebase.ps1" -Success $false -Detail "Missing"
} else {
  Add-CheckResult -Label "build_web_firebase.ps1" -Success $true -Detail "Found"
}

if (-not (Test-Path $deployScriptPath)) {
  $errors.Add("Deploy script is missing.")
  Add-CheckResult -Label "deploy_web_firebase.ps1" -Success $false -Detail "Missing"
} else {
  Add-CheckResult -Label "deploy_web_firebase.ps1" -Success $true -Detail "Found"
}

if ($null -ne $firebasePath) {
  $loginOutput = & $firebasePath login:list 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0 -or $loginOutput -match "No authorized accounts") {
    $errors.Add("Firebase CLI is not logged in.")
    Add-CheckResult -Label "Firebase login" -Success $false -Detail "Run firebase login"
  } else {
    Add-CheckResult -Label "Firebase login" -Success $true -Detail "Authorized account found"
  }
}

Write-Host ""
if ($errors.Count -eq 0) {
  Write-Host "Firebase Hosting preflight passed."
  exit 0
}

Write-Host "Firebase Hosting preflight failed. Fix the items marked [!!]."
exit 1
