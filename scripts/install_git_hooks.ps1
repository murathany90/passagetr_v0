param()

$ErrorActionPreference = 'Stop'
$repoRoot = (git rev-parse --show-toplevel).Trim()

if ([string]::IsNullOrWhiteSpace($repoRoot)) {
  throw 'Git repository root could not be resolved.'
}

Push-Location $repoRoot
try {
  git config core.hooksPath .githooks
  Write-Host 'Configured git hooks path: .githooks' -ForegroundColor Green
  Write-Host 'Pre-commit UTF-8 validation is now active for this repository.'
} finally {
  Pop-Location
}
