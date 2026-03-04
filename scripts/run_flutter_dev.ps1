param(
  [string]$ConfigFile = "env/app.dev.json"
)

if (-not (Test-Path $ConfigFile)) {
  Write-Error "Config file bulunamadi: $ConfigFile"
  Write-Host "Ornek dosyayi kopyalayin: Copy-Item env/app.dev.json.example env/app.dev.json"
  exit 1
}

flutter run --dart-define-from-file=$ConfigFile
