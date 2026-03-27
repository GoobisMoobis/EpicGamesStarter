$ErrorActionPreference = 'Stop'

$UserBasic = '34a02cf8f4414e29b15921876da36f9a'
$PwBasic = 'daafbccc737745039dffe53d94fc76cf'
$UserAgent = 'UELauncher/11.0.1-14907503+++Portal+Release-Live Windows/10.0.19041.1.256.64bit'

$BasicAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${UserBasic}:${PwBasic}"))
$TokenUrl = 'https://account-public-service-prod03.ol.epicgames.com/account/api/oauth/token'
$VerifyUrl = 'https://account-public-service-prod03.ol.epicgames.com/account/api/oauth/verify'
$ExchangeUrl = 'https://account-public-service-prod03.ol.epicgames.com/account/api/oauth/exchange'

# TokenStore 
function Get-TokenStorePath {
    $userHome = [Environment]::GetFolderPath('UserProfile')
    $legendary = Join-Path $userHome '.config\legendary\user.json'
    if (Test-Path $legendary) { return $legendary }

    $auPath = Join-Path $userHome 'AppData\LocalLow\Innersloth\Among Us'
    if (Test-Path $auPath) { return Join-Path $auPath 'EGSAuth.json' }

    return 'EGSAuth.json'
}

function Save-Tokens($session) {
    $path = Get-TokenStorePath
    $session | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
    Write-Host "[TokenStore] Session saved to $path"
}

function Import-Tokens {
    $path = Get-TokenStorePath
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw | ConvertFrom-Json }
    catch { return $null }
}

# EpicApi
function Invoke-EgsPost($body, $accessToken = $null) {
    $headers = @{ 'User-Agent' = $UserAgent }
    if ($accessToken) {
        $headers['Authorization'] = "Bearer $accessToken"
    } else {
        $headers['Authorization'] = "Basic $BasicAuth"
    }
    return Invoke-RestMethod -Uri $TokenUrl -Method Post -Headers $headers -Body $body -ContentType 'application/x-www-form-urlencoded'
}

function Start-Session($authCode = '', $refreshToken = '', $exchangeCode = '') {
    if ($refreshToken) {
        $body = "grant_type=refresh_token&refresh_token=$refreshToken&token_type=eg1"
    } elseif ($exchangeCode) {
        $body = "grant_type=exchange_code&exchange_code=$exchangeCode&token_type=eg1"
    } elseif ($authCode) {
        $body = "grant_type=authorization_code&code=$authCode&token_type=eg1"
    } else {
        throw 'At least one token type must be specified!'
    }
    return Invoke-EgsPost $body
}

function Resume-Session($accessToken) {
    $headers = @{
        'User-Agent' = $UserAgent
        'Authorization' = "Bearer $accessToken"
    }
    $result = Invoke-RestMethod -Uri $VerifyUrl -Method Get -Headers $headers
    if ($result.errorMessage) { throw "Session verify failed: $($result.errorCode)" }
    return $result
}

function Get-GameToken($accessToken) {
    $headers = @{
        'User-Agent' = $UserAgent
        'Authorization' = "Bearer $accessToken"
    }
    $result = Invoke-RestMethod -Uri $ExchangeUrl -Method Get -Headers $headers
    return $result.code
}

function Get-AuthUrl {
    $redirectUrl = [Uri]::EscapeDataString("https://www.epicgames.com/id/api/redirect?clientId=${UserBasic}&responseType=code")
    return "https://www.epicgames.com/id/login?redirectUrl=$redirectUrl"
}

# Main
if ((Get-Location).Path.Contains([Environment]::GetFolderPath('ProgramFiles'))) {
    Write-Host 'your AU copy is in program files, please move it somewhere else like desktop'
    Read-Host
}

if (-not (Test-Path 'Among Us.exe')) {
    Write-Host 'Among Us.exe not found in current directory, please place this file in the same folder as Among Us'
    Read-Host
    exit
}

Write-Host 'Starting Login Attempts'

$session = $null
$accessToken = $null
$saved = Import-Tokens

if ($saved) {
    $refreshToken = $saved.refresh_token
    $savedAccessToken = $saved.access_token

    if ($refreshToken) {
        Write-Host 'Found saved session. Attempting refresh...'
        try {
            $session = Start-Session -refreshToken $refreshToken
            $accessToken = $session.access_token
            Write-Host 'Refresh Successful!'
        } catch {
            Write-Host "Refresh failed (Token expired?): $($_.Exception.Message)"
        }
    }

    if (-not $session -and $savedAccessToken) {
        Write-Host 'Attempting to resume session with Access Token...'
        try {
            $session = Resume-Session $savedAccessToken
            $accessToken = $savedAccessToken
            Write-Host 'Session Resumed!'
        } catch {
            Write-Host 'Access Token expired.'
        }
    }
}

if (-not $session) {
    Write-Host ''
    Write-Host 'Manual Login Required'
    $authUrl = Get-AuthUrl
    Write-Host "1. Open this URL in your browser if it does not open automatically:"
    Write-Host $authUrl
    Start-Process $authUrl

    Write-Host "2. Copy Paste the 'authorizationCode' text showing on the browser into here."
    $code = (Read-Host 'Enter Code').Trim().Replace('"', '').Trim()

    if (-not $code) {
        Write-Host 'No code was provided, please try again by closing and re-running this file'
        Read-Host
        exit
    }

    try {
        $session = Start-Session -authCode $code
        $accessToken = $session.access_token
        Write-Host 'Login Successful!'
    } catch {
        Write-Host "FATAL: Login failed. $($_.Exception.Message)"
        Read-Host
        exit
    }
}

if ($session) {
    Save-Tokens $session
}

try {
    $gameToken = Get-GameToken $accessToken
    Write-Host 'READY TO LAUNCH'
    Start-Process 'Among Us.exe' -ArgumentList "-AUTH_PASSWORD=$gameToken"
    Write-Host 'Among Us Process started'
} catch {
    Write-Host "Failed to get launch token: $($_.Exception.Message)"
}

Write-Host ''
Write-Host 'Press any key to exit...'
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
