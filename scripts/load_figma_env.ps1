param(
  [string]$EnvFile = ".env.figma.local"
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$envFilePath = Join-Path $repoRoot $EnvFile

if (-not (Test-Path $envFilePath)) {
  throw "Figma env dosyasi bulunamadi: $EnvFile"
}

$loadedKeys = New-Object System.Collections.Generic.List[string]

foreach ($line in Get-Content $envFilePath -Encoding UTF8) {
  $trimmed = $line.Trim()
  if ([string]::IsNullOrWhiteSpace($trimmed)) {
    continue
  }

  if ($trimmed.StartsWith("#")) {
    continue
  }

  $parts = $trimmed -split "=", 2
  if ($parts.Count -ne 2) {
    continue
  }

  $key = $parts[0].Trim()
  $value = $parts[1].Trim()

  if (
    ($value.StartsWith('"') -and $value.EndsWith('"')) -or
    ($value.StartsWith("'") -and $value.EndsWith("'"))
  ) {
    $value = $value.Substring(1, $value.Length - 2)
  }

  [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
  $loadedKeys.Add($key)
}

if ($loadedKeys.Count -eq 0) {
  throw "Figma env dosyasindan hicbir key yuklenemedi: $EnvFile"
}

Write-Host "Yuklenen env key'leri: $($loadedKeys -join ', ')" -ForegroundColor Green

if ($env:FIGMA_ACCESS_TOKEN) {
  Write-Host "FIGMA_ACCESS_TOKEN hazir." -ForegroundColor Green
}
