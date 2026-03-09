param(
  [switch]$Fix,
  [switch]$StagedOnly,
  [switch]$TrackedOnly
)

$ErrorActionPreference = 'Stop'

$extensions = @(
  '.md', '.txt', '.yml', '.yaml', '.json', '.dart', '.ts', '.js', '.py', '.ps1', '.sql',
  '.xml', '.gradle', '.kts', '.plist', '.xcconfig', '.properties', '.cmake', '.cc', '.cpp', '.h'
)

$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$legacyEncoding = [System.Text.Encoding]::GetEncoding(1254)
$e2Euro = [string]::Concat([char]0x00E2, [char]0x20AC)
$mojibakeTokens = @(
  [string][char]0xFFFD,
  ([char]0x00C2).ToString(),
  ([char]0x00C3).ToString(),
  ([char]0x00C4).ToString(),
  ([char]0x00C5).ToString(),
  $e2Euro,
  [string]::Concat($e2Euro, [char]0x0153),
  [string]::Concat($e2Euro, [char]0x009D),
  [string]::Concat($e2Euro, [char]0x009C),
  [string]::Concat($e2Euro, [char]0x0094),
  [string]::Concat($e2Euro, [char]0x0093),
  [string]::Concat($e2Euro, [char]0x00A6),
  [string]::Concat($e2Euro, [char]0x00A2),
  [string]::Concat($e2Euro, [char]0x00A0)
)
$ignoredPathFragments = @(
  '\.agent\',
  '\.agents\',
  '\.claude\',
  '\docs\archive\',
  '\docs\gramer\',
  '\json_output\',
  '\docs\ENCODING.md',
  '\scripts\ensure_utf8.ps1',
  '\scripts\check_mojibake.py'
)

try {
  $root = (git rev-parse --show-toplevel 2>$null).Trim()
} catch {
  $root = ''
}

if ([string]::IsNullOrWhiteSpace($root)) {
  $root = (Get-Location).Path
}

function Get-TargetFiles {
  param(
    [switch]$StagedOnly,
    [switch]$TrackedOnly
  )

  if ($StagedOnly) {
    $items = @(git diff --cached --name-only --diff-filter=ACMR 2>$null)
    foreach ($item in $items) {
      if ([string]::IsNullOrWhiteSpace($item)) { continue }
      $fullPath = Join-Path $root $item
      if (Test-Path $fullPath -PathType Leaf) {
        (Resolve-Path $fullPath).Path
      }
    }
    return
  }

  if ($TrackedOnly) {
    $items = @(git ls-files 2>$null)
    foreach ($item in $items) {
      if ([string]::IsNullOrWhiteSpace($item)) { continue }
      $fullPath = Join-Path $root $item
      if (Test-Path $fullPath -PathType Leaf) {
        (Resolve-Path $fullPath).Path
      }
    }
    return
  }

  Get-ChildItem -Path $root -Recurse -File | ForEach-Object { $_.FullName }
}

$invalid = @()
$suspicious = @()
$targets = @(Get-TargetFiles -StagedOnly:$StagedOnly -TrackedOnly:$TrackedOnly) |
  Sort-Object -Unique |
  Where-Object { $extensions -contains [System.IO.Path]::GetExtension($_).ToLowerInvariant() } |
  Where-Object {
    $normalizedPath = $_
    -not ($ignoredPathFragments | Where-Object { $normalizedPath.Contains($_) })
  }

foreach ($path in $targets) {
  $bytes = [System.IO.File]::ReadAllBytes($path)
  try {
    $text = $utf8Strict.GetString($bytes)
  } catch {
    $invalid += $path
    if ($Fix) {
      $legacyText = $legacyEncoding.GetString($bytes)
      [System.IO.File]::WriteAllText($path, $legacyText, $utf8NoBom)
    }
    continue
  }

  $hits = @($mojibakeTokens | Where-Object { $_ -and $text.Contains($_) } | Select-Object -Unique)
  if ($hits.Count -gt 0) {
    $suspicious += [PSCustomObject]@{
      Path = $path
      Tokens = $hits
    }
  }
}

if ($Fix -and $invalid.Count -gt 0) {
  $targets = @(Get-TargetFiles -StagedOnly:$StagedOnly -TrackedOnly:$TrackedOnly) |
    Sort-Object -Unique |
    Where-Object { $extensions -contains [System.IO.Path]::GetExtension($_).ToLowerInvariant() } |
    Where-Object {
      $normalizedPath = $_
      -not ($ignoredPathFragments | Where-Object { $normalizedPath.Contains($_) })
    }
  $suspicious = @()
  foreach ($path in $targets) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $text = $utf8Strict.GetString($bytes)
    $hits = @($mojibakeTokens | Where-Object { $_ -and $text.Contains($_) } | Select-Object -Unique)
    if ($hits.Count -gt 0) {
      $suspicious += [PSCustomObject]@{
        Path = $path
        Tokens = $hits
      }
    }
  }
}

if ($invalid.Count -eq 0 -and $suspicious.Count -eq 0) {
  Write-Host 'All tracked text files are valid UTF-8 and look clean.'
  exit 0
}

if ($invalid.Count -gt 0) {
  Write-Host 'Invalid UTF-8 files detected:' -ForegroundColor Yellow
  $invalid | ForEach-Object {
    $_.Replace($root + '\', '') | Write-Host
  }
  Write-Host ''
}

if ($suspicious.Count -gt 0) {
  Write-Host 'Suspicious mojibake/replacement-character content detected:' -ForegroundColor Yellow
  $suspicious | ForEach-Object {
    $relativePath = $_.Path.Replace($root + '\', '')
    $tokens = ($_.Tokens | ForEach-Object { $_.Replace([string][char]0xFFFD, '\uFFFD') }) -join ', '
    Write-Host ('- ' + $relativePath + ' [' + $tokens + ']')
  }
  Write-Host ''
  Write-Host 'Use scripts\write_utf8.ps1 or apply_patch for large Turkish text updates.' -ForegroundColor Cyan
}

if ($Fix -and $invalid.Count -gt 0 -and $suspicious.Count -eq 0) {
  Write-Host ('Converted ' + $invalid.Count + ' file(s) from cp1254/ANSI to UTF-8.') -ForegroundColor Green
  exit 0
}

exit 1
