param(
  [string]$ProjectRef = "qretfjzaolpdguggcqfg",
  [string]$BaseUrl = "https://qretfjzaolpdguggcqfg.supabase.co",
  [string]$OutputJson = "docs/verification/phase01_supabase_connection/verification.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Invoke-SupabaseCliJson {
  param(
    [string[]]$Arguments
  )

  $output = & supabase @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Supabase CLI command failed: supabase $($Arguments -join ' ')"
  }

  return $output | ConvertFrom-Json
}

function Invoke-JsonRequest {
  param(
    [ValidateSet("Get", "Post", "Patch")]
    [string]$Method,
    [string]$Uri,
    [hashtable]$Headers,
    [object]$Body
  )

  $requestParams = @{
    Method  = $Method
    Uri     = $Uri
    Headers = $Headers
  }

  Write-Host "[$Method] $Uri"

  if ($null -ne $Body) {
    $requestParams["Body"] = ($Body | ConvertTo-Json -Depth 8 -Compress)
    $requestParams["ContentType"] = "application/json"
  }

  try {
    return Invoke-RestMethod @requestParams
  } catch {
    if ($_.Exception.Response -ne $null) {
      $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $bodyText = $reader.ReadToEnd()
      $reader.Close()
      Write-Host "Response body: $bodyText"
    }
    throw
  }
}

function Ensure-TestUser {
  param(
    [pscustomobject]$Account,
    [string]$ServiceRoleKey,
    [array]$ExistingUsers
  )

  $grantedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $headers = @{
    apikey        = $ServiceRoleKey
    Authorization = "Bearer $ServiceRoleKey"
  }

  $existingUser = $ExistingUsers | Where-Object { $_.email -eq $Account.email } | Select-Object -First 1
  if ($null -eq $existingUser) {
    try {
      $existingUser = Invoke-JsonRequest `
        -Method Post `
        -Uri "$BaseUrl/auth/v1/admin/users" `
        -Headers $headers `
        -Body @{
          email         = $Account.email
          password      = $Account.password
          email_confirm = $true
          user_metadata = @{
            display_name = $Account.display_name
          }
        }
      Start-Sleep -Milliseconds 300
    } catch {
      $existingUser = (
        Invoke-JsonRequest `
          -Method Get `
          -Uri "$BaseUrl/auth/v1/admin/users" `
          -Headers $headers `
          -Body $null
      ).users | Where-Object { $_.email -eq $Account.email } | Select-Object -First 1

      if ($null -eq $existingUser) {
        throw
      }
    }
  }

  Invoke-JsonRequest `
    -Method Patch `
    -Uri "$BaseUrl/rest/v1/profiles?user_id=eq.$($existingUser.id)" `
    -Headers ($headers + @{
      Prefer = "return=minimal"
    }) `
    -Body @{
      display_name         = $Account.display_name
      preferred_locale     = "tr"
      theme_mode           = "system"
      onboarding_completed = $true
      is_anonymous         = $false
    } | Out-Null

  Invoke-JsonRequest `
    -Method Post `
    -Uri "$BaseUrl/rest/v1/user_roles?on_conflict=user_id,role" `
    -Headers ($headers + @{
      Prefer = "resolution=merge-duplicates,return=minimal"
    }) `
    -Body @(
      @{
        user_id    = $existingUser.id
        role       = "user"
        granted_at = $grantedAt
        revoked_at = $null
      }
    ) | Out-Null

  if ($Account.role -ne "user") {
    Invoke-JsonRequest `
      -Method Post `
      -Uri "$BaseUrl/rest/v1/user_roles?on_conflict=user_id,role" `
      -Headers ($headers + @{
        Prefer = "resolution=merge-duplicates,return=minimal"
      }) `
      -Body @(
        @{
          user_id    = $existingUser.id
          role       = $Account.role
          granted_at = $grantedAt
          revoked_at = $null
        }
      ) | Out-Null
  }

  $existingEntitlements = Invoke-JsonRequest `
    -Method Get `
    -Uri "$BaseUrl/rest/v1/entitlements?select=id,plan,revoked_at&user_id=eq.$($existingUser.id)&plan=eq.$($Account.plan)&revoked_at=is.null" `
    -Headers $headers `
    -Body $null

  if (($existingEntitlements | Measure-Object).Count -eq 0) {
    Invoke-JsonRequest `
      -Method Post `
      -Uri "$BaseUrl/rest/v1/entitlements" `
      -Headers ($headers + @{
        Prefer = "return=minimal"
      }) `
      -Body @{
        user_id = $existingUser.id
        plan    = $Account.plan
        source  = "phase1_seed"
      } | Out-Null
  }

  return $existingUser
}

function Sign-InForVerification {
  param(
    [pscustomobject]$Account,
    [string]$PublishableKey
  )

  return Invoke-JsonRequest `
    -Method Post `
    -Uri "$BaseUrl/auth/v1/token?grant_type=password" `
    -Headers @{
      apikey = $PublishableKey
    } `
    -Body @{
      email    = $Account.email
      password = $Account.password
    }
}

function Invoke-UserRpc {
  param(
    [string]$AccessToken,
    [string]$PublishableKey,
    [string]$FunctionName,
    [object]$Body
  )

  return Invoke-JsonRequest `
    -Method Post `
    -Uri "$BaseUrl/rest/v1/rpc/$FunctionName" `
    -Headers @{
      apikey        = $PublishableKey
      Authorization = "Bearer $AccessToken"
    } `
    -Body $Body
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputJson) | Out-Null

$keys = Invoke-SupabaseCliJson -Arguments @("projects", "api-keys", "--project-ref", $ProjectRef, "-o", "json")
$publishableKey = ($keys | Where-Object { $_.type -eq "publishable" } | Select-Object -First 1).api_key
$serviceRoleKey = ($keys | Where-Object { $_.id -eq "service_role" } | Select-Object -First 1).api_key

if ([string]::IsNullOrWhiteSpace($publishableKey) -or [string]::IsNullOrWhiteSpace($serviceRoleKey)) {
  throw "Could not resolve publishable or service_role key from Supabase CLI."
}

$accounts = @(
  [pscustomobject]@{
    key          = "free"
    email        = "phase1.free@passagetr.dev"
    password     = "PassageTR#2026!"
    display_name = "Phase 1 Free"
    role         = "user"
    plan         = "free"
  },
  [pscustomobject]@{
    key          = "pro"
    email        = "phase1.pro@passagetr.dev"
    password     = "PassageTR#2026!"
    display_name = "Phase 1 Pro"
    role         = "user"
    plan         = "pro"
  },
  [pscustomobject]@{
    key          = "admin"
    email        = "phase1.admin@passagetr.dev"
    password     = "PassageTR#2026!"
    display_name = "Phase 1 Admin"
    role         = "admin"
    plan         = "free"
  },
  [pscustomobject]@{
    key          = "developer"
    email        = "phase1.developer@passagetr.dev"
    password     = "PassageTR#2026!"
    display_name = "Phase 1 Developer"
    role         = "developer"
    plan         = "free"
  }
)

$existingUsers = (Invoke-JsonRequest `
  -Method Get `
  -Uri "$BaseUrl/auth/v1/admin/users" `
  -Headers @{
    apikey        = $serviceRoleKey
    Authorization = "Bearer $serviceRoleKey"
  } `
  -Body $null).users

$summary = @()

foreach ($account in $accounts) {
  $user = Ensure-TestUser -Account $account -ServiceRoleKey $serviceRoleKey -ExistingUsers $existingUsers
  $session = Sign-InForVerification -Account $account -PublishableKey $publishableKey
  $accessToken = $session.access_token

  $resolvedRole = Invoke-UserRpc `
    -AccessToken $accessToken `
    -PublishableKey $publishableKey `
    -FunctionName "current_app_role" `
    -Body @{}
  $resolvedPlan = Invoke-UserRpc `
    -AccessToken $accessToken `
    -PublishableKey $publishableKey `
    -FunctionName "current_plan" `
    -Body @{}
  $canReadPro = Invoke-UserRpc `
    -AccessToken $accessToken `
    -PublishableKey $publishableKey `
    -FunctionName "can_read_published_content" `
    -Body @{
      p_is_published = $true
      p_is_pro       = $true
    }

  $visibleProfiles = Invoke-JsonRequest `
    -Method Get `
    -Uri "$BaseUrl/rest/v1/profiles?select=user_id&limit=5" `
    -Headers @{
      apikey        = $publishableKey
      Authorization = "Bearer $accessToken"
    } `
    -Body $null

  $summary += [pscustomobject]@{
    key               = $account.key
    email             = $account.email
    user_id           = $user.id
    expected_role     = $account.role
    expected_plan     = $account.plan
    resolved_role     = $resolvedRole
    resolved_plan     = $resolvedPlan
    can_read_pro      = [bool]$canReadPro
    visible_profiles  = ($visibleProfiles | Measure-Object).Count
    password_hint     = $account.password
  }
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputJson -Encoding utf8
$summary | Format-Table key,email,resolved_role,resolved_plan,can_read_pro,visible_profiles -AutoSize
Write-Host "Saved verification output to $OutputJson"
