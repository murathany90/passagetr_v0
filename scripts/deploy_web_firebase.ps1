param(
  [ValidateSet("student_app", "admin_console")]
  [string]$AppName = "student_app",
  [string]$EnvironmentFile = "env/app.web.json",
  [switch]$SkipAnalyze,
  [switch]$SkipTests,
  [switch]$SkipSmoke,
  [switch]$SkipDeploy,
  [int]$SmokePort = 8130
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$buildScript = Join-Path $scriptRoot "build_web_firebase.ps1"
$buildRoot = Join-Path $repoRoot "build\web"

function Resolve-ToolPath {
  param([string]$ToolName)

  $command = Get-Command $ToolName -ErrorAction SilentlyContinue
  if ($null -eq $command) {
    throw "Required tool not found in PATH: $ToolName"
  }

  return $command.Source
}

function Start-StaticWebServer {
  param(
    [string]$Root,
    [int]$Port
  )

  $job = Start-Job -ArgumentList $Root, $Port -ScriptBlock {
    param($Root, $Port)

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
    $listener.Prefixes.Add("http://127.0.0.1:$Port/")
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

function Invoke-LocalSmoke {
  param([int]$Port)

  $checks = @(
    @{ Path = "/"; Contains = "flutter_bootstrap.js" },
    @{ Path = "/index.html"; Contains = "flutter_bootstrap.js" },
    @{ Path = "/main.dart.js"; Contains = "" },
    @{ Path = "/flutter_bootstrap.js"; Contains = "" },
    @{ Path = "/version.json"; Contains = "" },
    @{ Path = "/profile"; Contains = "flutter_bootstrap.js" }
  )

  foreach ($check in $checks) {
    $url = "http://127.0.0.1:$Port$($check.Path)"
    $response = Invoke-WebRequest -UseBasicParsing $url
    if ($response.StatusCode -ne 200) {
      throw "Smoke check failed for $url with status $($response.StatusCode)"
    }

    if ($check.Contains -and ($response.Content -notmatch [regex]::Escape($check.Contains))) {
      throw "Smoke check failed for $url because expected marker was not found."
    }
  }
}

if (-not (Test-Path $buildScript)) {
  throw "Build script not found: $buildScript"
}

Push-Location $repoRoot
try {
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

  if (-not $SkipSmoke) {
    $job = Start-StaticWebServer -Root $buildRoot -Port $SmokePort
    try {
      Write-Host "Running local web smoke checks on http://127.0.0.1:$SmokePort ..."
      Invoke-LocalSmoke -Port $SmokePort
    } finally {
      Stop-Job $job -ErrorAction SilentlyContinue | Out-Null
      Remove-Job $job -Force -ErrorAction SilentlyContinue | Out-Null
    }
  }

  if ($SkipDeploy) {
    Write-Host "SkipDeploy enabled. Firebase deploy step was skipped."
    return
  }

  $firebase = Resolve-ToolPath -ToolName "firebase"
  Write-Host "Deploying Firebase Hosting..."
  & $firebase deploy --only hosting
} finally {
  Pop-Location
}
