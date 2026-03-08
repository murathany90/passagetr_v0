param(
  [switch]$Fix
)

$ErrorActionPreference = 'Stop'

$extensions = @(
  '.md', '.txt', '.yml', '.yaml', '.json', '.dart', '.ts', '.js', '.py', '.ps1', '.sql',
  '.xml', '.gradle', '.kts', '.plist', '.xcconfig', '.properties', '.cmake', '.cc', '.cpp', '.h'
)

$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$legacyEncoding = [System.Text.Encoding]::GetEncoding(1254)
$root = (Get-Location).Path
$invalid = @()

Get-ChildItem -Path $root -Recurse -File |
  Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
  ForEach-Object {
    $path = $_.FullName
    $bytes = [System.IO.File]::ReadAllBytes($path)
    try {
      [void]$utf8Strict.GetString($bytes)
    } catch {
      $invalid += $path
      if ($Fix) {
        $text = $legacyEncoding.GetString($bytes)
        [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
      }
    }
  }

if ($invalid.Count -eq 0) {
  Write-Host 'All tracked text files are valid UTF-8.'
  exit 0
}

Write-Host 'Invalid UTF-8 files detected:' -ForegroundColor Yellow
$invalid | ForEach-Object {
  $_.Replace($root + '\\', '') | Write-Host
}

if ($Fix) {
  Write-Host ''
  Write-Host ('Converted ' + $invalid.Count + ' file(s) from cp1254/ANSI to UTF-8.') -ForegroundColor Green
  exit 0
}

exit 1