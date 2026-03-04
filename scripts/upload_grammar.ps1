param(
  [ValidateSet("upsert", "replace")]
  [string]$Mode = "replace",
  [string]$JsonFile = "json_output/tum_gramer_modulleri.json",
  [switch]$DryRun
)

if (-not (Test-Path ".env")) {
  Write-Error ".env bulunamadi. Ornek olusturun:"
  Write-Host '@"'
  Write-Host 'SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co'
  Write-Host 'SUPABASE_SERVICE_ROLE_KEY=sb_secret_xxx'
  Write-Host '"@ | Set-Content .env -Encoding utf8'
  exit 1
}

$dry = ""
if ($DryRun) {
  $dry = "--dry-run"
}

python supabase_uploader.py --json-file $JsonFile --mode $Mode $dry
