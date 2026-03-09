param(
  [string]$VerificationJson = "docs/verification/phase01_supabase_connection/verification.json",
  [switch]$RefreshAccounts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$verificationPath = Join-Path $repoRoot $VerificationJson
$seedScript = Join-Path $scriptRoot "seed_supabase_phase1_test_accounts.ps1"

if ($RefreshAccounts -or -not (Test-Path $verificationPath)) {
  if (-not (Test-Path $seedScript)) {
    throw "Seed script not found: $seedScript"
  }

  & powershell -ExecutionPolicy Bypass -File $seedScript -OutputJson $VerificationJson
  if ($LASTEXITCODE -ne 0) {
    throw "Seed + verification script failed."
  }
}

if (-not (Test-Path $verificationPath)) {
  throw "Verification file not found: $verificationPath"
}

$rows = Get-Content $verificationPath -Raw | ConvertFrom-Json
if ($null -eq $rows -or ($rows | Measure-Object).Count -eq 0) {
  throw "Verification file is empty: $verificationPath"
}

$expectations = @{
  free = @{
    role = "user"
    plan = "free"
    canReadPro = $false
  }
  pro = @{
    role = "user"
    plan = "pro"
    canReadPro = $true
  }
  admin = @{
    role = "admin"
    plan = "free"
    canReadPro = $true
  }
  developer = @{
    role = "developer"
    plan = "free"
    canReadPro = $true
  }
}

foreach ($entry in $rows) {
  if (-not $expectations.ContainsKey($entry.key)) {
    continue
  }

  $expected = $expectations[$entry.key]
  if ($entry.resolved_role -ne $expected.role) {
    throw "RLS smoke failed for $($entry.key): expected role $($expected.role), got $($entry.resolved_role)"
  }
  if ($entry.resolved_plan -ne $expected.plan) {
    throw "RLS smoke failed for $($entry.key): expected plan $($expected.plan), got $($entry.resolved_plan)"
  }
  if ([bool]$entry.can_read_pro -ne $expected.canReadPro) {
    throw "RLS smoke failed for $($entry.key): expected can_read_pro=$($expected.canReadPro), got $($entry.can_read_pro)"
  }
  if ([int]$entry.visible_profiles -lt 1) {
    throw "RLS smoke failed for $($entry.key): visible_profiles should be at least 1."
  }
}

Write-Host "Supabase RLS smoke passed using $verificationPath"
