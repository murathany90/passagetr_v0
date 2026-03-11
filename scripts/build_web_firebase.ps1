param(
  [ValidateSet("student_app", "admin_console")]
  [string]$AppName = "student_app",
  [string]$EnvironmentFile = "env/app.web.json",
  [ValidateSet("auto", "html", "canvaskit", "wasm")]
  [string]$WebRenderer = "auto",
  [switch]$SkipAnalyze,
  [switch]$SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$appRoot = Join-Path $repoRoot "apps\$AppName"
$appBuildRoot = Join-Path $appRoot "build\web"
$hostingBuildRoot = Join-Path $repoRoot "build\hosting\$AppName"
$envFilePath = Join-Path $repoRoot $EnvironmentFile
$appPubspecPath = Join-Path $appRoot "pubspec.yaml"
$workspaceInfoPath = Join-Path $repoRoot "packages\shared_core\lib\src\workspace_info.dart"
$releaseCatalogPath = Join-Path $repoRoot "packages\shared_core\lib\src\release\release_catalog.dart"
$changelogPath = Join-Path $repoRoot "docs\release\CHANGELOG.md"

$requiredFiles = @(
  "index.html",
  "main.dart.js",
  "flutter_bootstrap.js",
  "version.json"
)

$blockedFiles = @(
  "db_probe.dart",
  "db_probe.html",
  "db_probe.js",
  "db_probe.js.deps",
  "db_probe.js.map",
  "drift_worker.dart",
  "drift_worker.dart.js",
  "drift_worker.dart.js.deps",
  "drift_worker.dart.js.map",
  "sqlite3.wasm"
)

function Get-ReleaseMetadata {
  param([string]$WorkspaceInfoPath)

  if (-not (Test-Path $WorkspaceInfoPath)) {
    throw "Workspace info file not found: $WorkspaceInfoPath"
  }

  $content = Get-Content $WorkspaceInfoPath -Raw

  $appVersionMatch = [regex]::Match($content, "static const appVersion = '([^']+)';")
  $buildNumberMatch = [regex]::Match($content, "static const buildNumber = '([^']+)';")
  $releaseNotesPathMatch = [regex]::Match($content, "static const releaseNotesPath = '([^']+)';")

  if (-not $appVersionMatch.Success) {
    throw "Could not parse appVersion from $WorkspaceInfoPath"
  }
  if (-not $buildNumberMatch.Success) {
    throw "Could not parse buildNumber from $WorkspaceInfoPath"
  }
  if (-not $releaseNotesPathMatch.Success) {
    throw "Could not parse releaseNotesPath from $WorkspaceInfoPath"
  }

  $displayVersion = $appVersionMatch.Groups[1].Value.Trim()
  $numericVersion = if ($displayVersion.StartsWith("v")) {
    $displayVersion.Substring(1)
  } else {
    $displayVersion
  }

  return [pscustomobject]@{
    DisplayVersion = $displayVersion
    NumericVersion = $numericVersion
    BuildNumber = $buildNumberMatch.Groups[1].Value.Trim()
    ReleaseNotesPath = $releaseNotesPathMatch.Groups[1].Value.Trim()
  }
}

function Assert-ReleaseMetadata {
  param(
    [object]$ReleaseMetadata,
    [string]$AppPubspecPath,
    [string]$ReleaseCatalogPath,
    [string]$ChangelogPath
  )

  if (-not (Test-Path $AppPubspecPath)) {
    throw "App pubspec not found: $AppPubspecPath"
  }

  $pubspecContent = Get-Content $AppPubspecPath -Raw
  $pubspecVersionMatch = [regex]::Match($pubspecContent, "(?m)^version:\s*([^\r\n]+)")
  if (-not $pubspecVersionMatch.Success) {
    throw "Could not parse version from $AppPubspecPath"
  }

  $expectedPubspecVersion = "$($ReleaseMetadata.NumericVersion)+$($ReleaseMetadata.BuildNumber)"
  $actualPubspecVersion = $pubspecVersionMatch.Groups[1].Value.Trim()
  if ($actualPubspecVersion -ne $expectedPubspecVersion) {
    throw "App pubspec version drift detected in $AppPubspecPath. Expected $expectedPubspecVersion but found $actualPubspecVersion"
  }

  if (-not (Test-Path $ReleaseCatalogPath)) {
    throw "Release catalog file not found: $ReleaseCatalogPath"
  }

  $releaseCatalogContent = Get-Content $ReleaseCatalogPath -Raw
  if ($releaseCatalogContent -notmatch [regex]::Escape($ReleaseMetadata.DisplayVersion)) {
    throw "Current release version $($ReleaseMetadata.DisplayVersion) is missing from $ReleaseCatalogPath"
  }

  if (-not (Test-Path $ChangelogPath)) {
    throw "Changelog file not found: $ChangelogPath"
  }

  $changelogContent = Get-Content $ChangelogPath -Raw
  if ($changelogContent -notmatch [regex]::Escape($ReleaseMetadata.DisplayVersion)) {
    throw "Current release version $($ReleaseMetadata.DisplayVersion) is missing from $ChangelogPath"
  }
}

function Write-VersionManifest {
  param(
    [string]$Root,
    [string]$AppName,
    [object]$ReleaseMetadata
  )

  $versionPayload = [ordered]@{
    app_name = $AppName
    version = $ReleaseMetadata.NumericVersion
    display_version = $ReleaseMetadata.DisplayVersion
    build_number = $ReleaseMetadata.BuildNumber
    package_name = $AppName
    changelog_path = $ReleaseMetadata.ReleaseNotesPath
    released_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  } | ConvertTo-Json -Compress

  $versionPath = Join-Path $Root "version.json"
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($versionPath, $versionPayload, $utf8NoBom)
}

function Resolve-ToolPath {
  param([string]$ToolName)

  $command = Get-Command $ToolName -ErrorAction SilentlyContinue
  if ($null -eq $command) {
    throw "Required tool not found in PATH: $ToolName"
  }

  return $command.Source
}

function Get-DirectorySizeMb {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return [double]0
  }

  $sum = (Get-ChildItem $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
  if ($null -eq $sum) {
    return [double]0
  }

  return [math]::Round(($sum / 1MB), 2)
}

function Remove-PathIfPresent {
  param([string]$Path)

  if (Test-Path $Path) {
    Remove-Item $Path -Recurse -Force
  }
}

function Invoke-ProductionPrune {
  param([string]$Root)

  $databaseDirectory = Join-Path $Root "assets\assets\db"
  Remove-PathIfPresent -Path $databaseDirectory

  foreach ($relativePath in $blockedFiles) {
    Remove-PathIfPresent -Path (Join-Path $Root $relativePath)
  }
}

function Assert-BuildOutput {
  param([string]$Root)

  foreach ($requiredFile in $requiredFiles) {
    $fullPath = Join-Path $Root $requiredFile
    if (-not (Test-Path $fullPath)) {
      throw "Required web artifact missing: $requiredFile"
    }
  }

  $dbDirectory = Join-Path $Root "assets\assets\db"
  if (Test-Path $dbDirectory) {
    throw "Production web bundle still contains local db assets: $dbDirectory"
  }

  foreach ($relativePath in $blockedFiles) {
    $fullPath = Join-Path $Root $relativePath
    if (Test-Path $fullPath) {
      throw "Production web bundle still contains blocked artifact: $relativePath"
    }
  }
}

function Copy-BuildToHostingRoot {
  param(
    [string]$SourceRoot,
    [string]$DestinationRoot
  )

  Remove-PathIfPresent -Path $DestinationRoot
  New-Item -ItemType Directory -Path $DestinationRoot | Out-Null
  Copy-Item -Path (Join-Path $SourceRoot "*") -Destination $DestinationRoot -Recurse -Force
}

if (-not (Test-Path $appRoot)) {
  throw "Application path not found: $appRoot"
}

if (-not (Test-Path $envFilePath)) {
  throw "Environment file not found: $EnvironmentFile"
}

$effectiveWebRenderer = if ($WebRenderer -eq "auto" -and $AppName -eq "admin_console") {
  "html"
} else {
  $WebRenderer
}

$releaseMetadata = Get-ReleaseMetadata -WorkspaceInfoPath $workspaceInfoPath
Assert-ReleaseMetadata `
  -ReleaseMetadata $releaseMetadata `
  -AppPubspecPath $appPubspecPath `
  -ReleaseCatalogPath $releaseCatalogPath `
  -ChangelogPath $changelogPath

$flutter = Resolve-ToolPath -ToolName "flutter"

Push-Location $repoRoot
try {
  if (-not $SkipAnalyze) {
    Write-Host "Running flutter analyze..."
    & $flutter analyze
  }

  if (-not $SkipTests) {
    Write-Host "Running app tests for $AppName..."
    & $flutter test "apps/$AppName"
  }

  Write-Host "Building production web bundle for $AppName..."
  Push-Location $appRoot
  try {
    $buildArgs = @(
      "build",
      "web",
      "--release",
      "--dart-define-from-file=$envFilePath"
    )

    switch ($effectiveWebRenderer) {
      "wasm" {
        $buildArgs += "--wasm"
      }
      "html" {
        Write-Host "Explicit html renderer selection is not supported by this Flutter toolchain. Using default web build output."
      }
      "canvaskit" {
        Write-Host "Explicit canvaskit renderer selection is not supported by this Flutter toolchain. Using default web build output."
      }
      default {
        if ($effectiveWebRenderer -ne "auto") {
          Write-Host "Unknown web renderer value '$effectiveWebRenderer'. Using default web build output."
        }
      }
    }

    & $flutter @buildArgs
  } finally {
    Pop-Location
  }

  $sizeBeforePruneMb = Get-DirectorySizeMb -Path $appBuildRoot
  Write-Host "App build size before prune: $sizeBeforePruneMb MB"

  Write-VersionManifest `
    -Root $appBuildRoot `
    -AppName $AppName `
    -ReleaseMetadata $releaseMetadata

  Invoke-ProductionPrune -Root $appBuildRoot
  Assert-BuildOutput -Root $appBuildRoot

  Copy-BuildToHostingRoot -SourceRoot $appBuildRoot -DestinationRoot $hostingBuildRoot
  Write-VersionManifest `
    -Root $hostingBuildRoot `
    -AppName $AppName `
    -ReleaseMetadata $releaseMetadata
  Assert-BuildOutput -Root $hostingBuildRoot

  $sizeAfterPruneMb = Get-DirectorySizeMb -Path $hostingBuildRoot
  Write-Host "Hosting bundle size after prune: $sizeAfterPruneMb MB"
  Write-Host "Firebase web bundle is ready at $hostingBuildRoot"
} finally {
  Pop-Location
}
