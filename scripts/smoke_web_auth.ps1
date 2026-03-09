param(
  [ValidateSet("student_app")]
  [string]$AppName = "student_app",
  [string]$EnvironmentFile = "env/app.web.json",
  [switch]$SkipBuild,
  [switch]$SkipAnalyze,
  [switch]$SkipTests,
  [int]$Port = 8140
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$buildScript = Join-Path $scriptRoot "build_web_firebase.ps1"
$smokeScript = Join-Path $scriptRoot "web_auth_smoke_playwright.js"
$buildRoot = Join-Path $repoRoot "build\web"
$runnerRoot = Join-Path $repoRoot "temp\playwright-web-auth"

function Start-StaticWebServer {
  param(
    [string]$Root,
    [int]$ServerPort
  )

  $job = Start-Job -ArgumentList $Root, $ServerPort -ScriptBlock {
    param($Root, $ServerPort)

    $ErrorActionPreference = "Stop"

    function Get-ContentType {
      param([string]$Path)

      switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".html" { return "text/html; charset=utf-8" }
        ".js" { return "application/javascript; charset=utf-8" }
        ".json" { return "application/json; charset=utf-8" }
        ".css" { return "text/css; charset=utf-8" }
        ".wasm" { return "application/wasm" }
        default { return "application/octet-stream" }
      }
    }

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://127.0.0.1:$ServerPort/")
    $listener.Start()

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

          $candidatePath = Join-Path $Root ($relativePath -replace "/", "\")
          if ((Test-Path $candidatePath) -and -not (Get-Item $candidatePath).PSIsContainer) {
            $resolvedPath = $candidatePath
          } else {
            $resolvedPath = Join-Path $Root "index.html"
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
  }

  Start-Sleep -Seconds 2
  return $job
}

if (-not $SkipBuild) {
  $buildArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", $buildScript,
    "-AppName", $AppName,
    "-EnvironmentFile", $EnvironmentFile
  )

  if ($SkipAnalyze) {
    $buildArgs += "-SkipAnalyze"
  }
  if ($SkipTests) {
    $buildArgs += "-SkipTests"
  }

  & powershell.exe @buildArgs
}

if (-not (Test-Path $smokeScript)) {
  throw "Smoke script not found: $smokeScript"
}

if (-not (Test-Path $buildRoot)) {
  throw "Hosting build not found: $buildRoot"
}

New-Item -ItemType Directory -Path $runnerRoot -Force | Out-Null
if (-not (Test-Path (Join-Path $runnerRoot "node_modules\playwright"))) {
  npm install --prefix $runnerRoot playwright
}

$job = Start-StaticWebServer -Root $buildRoot -ServerPort $Port
try {
  $env:NODE_PATH = Join-Path $runnerRoot "node_modules"
  node $smokeScript "http://127.0.0.1:$Port"
} finally {
  Stop-Job $job -ErrorAction SilentlyContinue | Out-Null
  Remove-Job $job -Force -ErrorAction SilentlyContinue | Out-Null
}
