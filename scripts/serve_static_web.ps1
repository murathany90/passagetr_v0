param(
  [string]$Root = "build/web",
  [int]$Port = 8150
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repoRoot = Split-Path -Parent $PSScriptRoot
$resolvedRoot = (Resolve-Path (Join-Path $repoRoot $Root)).Path

function Get-ContentType {
  param([string]$Path)

  switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    ".html" { "text/html; charset=utf-8" }
    ".js" { "application/javascript; charset=utf-8" }
    ".css" { "text/css; charset=utf-8" }
    ".json" { "application/json; charset=utf-8" }
    ".wasm" { "application/wasm" }
    ".png" { "image/png" }
    ".jpg" { "image/jpeg" }
    ".jpeg" { "image/jpeg" }
    ".webp" { "image/webp" }
    ".svg" { "image/svg+xml" }
    default { "application/octet-stream" }
  }
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

Write-Host "Serving $resolvedRoot at http://127.0.0.1:$Port"

try {
  while ($listener.IsListening) {
    try {
      $context = $listener.GetContext()
    } catch {
      break
    }

    try {
      $relativePath = [System.Uri]::UnescapeDataString(
        $context.Request.Url.AbsolutePath.TrimStart("/")
      )
      if ([string]::IsNullOrWhiteSpace($relativePath)) {
        $relativePath = "index.html"
      }

      $candidatePath = Join-Path $resolvedRoot ($relativePath -replace "/", "\")
      if ((Test-Path $candidatePath) -and -not (Get-Item $candidatePath).PSIsContainer) {
        $resolvedPath = $candidatePath
      } else {
        $resolvedPath = Join-Path $resolvedRoot "index.html"
      }

      $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)
      $context.Response.StatusCode = 200
      $context.Response.ContentType = Get-ContentType -Path $resolvedPath
      $context.Response.ContentLength64 = $bytes.Length
      $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } finally {
      $context.Response.OutputStream.Close()
    }
  }
} finally {
  $listener.Stop()
  $listener.Close()
}
