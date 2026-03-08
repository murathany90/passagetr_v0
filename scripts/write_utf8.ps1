param(
  [Parameter(Mandatory = $true)]
  [string]$Path,
  [string]$Text,
  [string]$InputFile
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if ($PSBoundParameters.ContainsKey('Text')) {
  $content = $Text
} elseif ($PSBoundParameters.ContainsKey('InputFile')) {
  $sourcePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InputFile)
  $content = [System.IO.File]::ReadAllText($sourcePath, [System.Text.Encoding]::UTF8)
} elseif ($MyInvocation.ExpectingInput) {
  $content = [Console]::In.ReadToEnd()
} else {
  throw 'Provide -Text, -InputFile, or pipe content into the script.'
}

$targetPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
$parentPath = Split-Path $targetPath -Parent

if ($parentPath -and -not (Test-Path $parentPath)) {
  New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
}

[System.IO.File]::WriteAllText($targetPath, $content, $utf8NoBom)
Write-Host ('Wrote UTF-8 (no BOM): ' + $targetPath)
