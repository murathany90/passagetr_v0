param(
  [ValidateSet("student_app", "admin_console")]
  [string]$AppName = "student_app",
  [string]$EnvironmentFile = "env/app.web.json"
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
$smokeScriptPath = Join-Path $scriptRoot "smoke_web_auth.ps1"
$appRoot = Join-Path $repoRoot "apps\$AppName"

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

if (-not (Test-Path $appRoot)) {
  $errors.Add("Application path is missing: apps/$AppName")
  Add-CheckResult -Label "App path" -Success $false -Detail "apps/$AppName"
} else {
  Add-CheckResult -Label "App path" -Success $true -Detail "apps/$AppName"
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
    try {
      $firebasercJson = $firebasercContent | ConvertFrom-Json
      $projectId = [string]$firebasercJson.projects.default
      $hostingTargets = $firebasercJson.targets.$projectId.hosting
      $hasHostingTarget = $null -ne $hostingTargets -and $null -ne $hostingTargets.$AppName
      if (-not $hasHostingTarget) {
        $errors.Add(".firebaserc does not define hosting target '$AppName'.")
        Add-CheckResult -Label ".firebaserc" -Success $false -Detail "Hosting target '$AppName' missing"
      } else {
        Add-CheckResult -Label ".firebaserc" -Success $true -Detail "Project id and hosting target configured"
      }
    } catch {
      $errors.Add(".firebaserc could not be parsed as JSON.")
      Add-CheckResult -Label ".firebaserc" -Success $false -Detail "JSON parse hatasi"
    }
  }
}

if (-not (Test-Path $envFilePath)) {
  $errors.Add("Environment file is missing: $EnvironmentFile")
  Add-CheckResult -Label "Environment file" -Success $false -Detail $EnvironmentFile
} else {
  try {
    $envJson = Get-Content $envFilePath -Raw | ConvertFrom-Json
    $supabaseUrl = [string]$envJson.SUPABASE_URL
    $supabaseAnonKey = [string]$envJson.SUPABASE_ANON_KEY
    $hasUrl = -not [string]::IsNullOrWhiteSpace($supabaseUrl)
    $hasKey = -not [string]::IsNullOrWhiteSpace($supabaseAnonKey)
    $hasPlaceholder = $supabaseUrl -match "YOUR_PROJECT_REF" -or $supabaseAnonKey -match "sb_publishable_xxx"
    if (-not $hasUrl -or -not $hasKey -or $hasPlaceholder) {
      $errors.Add("Environment file does not contain real Supabase publishable credentials.")
      Add-CheckResult -Label "Environment file" -Success $false -Detail "SUPABASE_URL / SUPABASE_ANON_KEY kontrol edin"
    } else {
      Add-CheckResult -Label "Environment file" -Success $true -Detail $EnvironmentFile
    }
  } catch {
    $errors.Add("Environment file is not valid JSON: $EnvironmentFile")
    Add-CheckResult -Label "Environment file" -Success $false -Detail "JSON parse hatasi"
  }
}

foreach ($scriptInfo in @(
  @{ Path = $buildScriptPath; Label = "build_web_firebase.ps1" },
  @{ Path = $deployScriptPath; Label = "deploy_web_firebase.ps1" },
  @{ Path = $smokeScriptPath; Label = "smoke_web_auth.ps1" }
)) {
  if (-not (Test-Path $scriptInfo.Path)) {
    $errors.Add("$($scriptInfo.Label) is missing.")
    Add-CheckResult -Label $scriptInfo.Label -Success $false -Detail "Missing"
  } else {
    Add-CheckResult -Label $scriptInfo.Label -Success $true -Detail "Found"
  }
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
