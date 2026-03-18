# get_my_skins.ps1
Write-Host "Getting your purchased skins..." -ForegroundColor Cyan

$possiblePaths = @(
    "C:\Riot Games\League of Legends\lockfile",
    "$env:USERPROFILE\AppData\Local\Riot Games\Riot Client\Config\lockfile",
    "$env:USERPROFILE\AppData\Local\Riot Games\League of Legends\Config\lockfile"
)

$lockfileFound = $false
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $lcuPath = $path
        $lockfileFound = $true
        Write-Host "Found lockfile: $path" -ForegroundColor Green
        break
    }
}

if (-not $lockfileFound) {
    Write-Host "ERROR: League of Legends is not running!" -ForegroundColor Red
    Write-Host "Please start League of Legends and try again." -ForegroundColor Yellow
    pause
    exit
}

$content = Get-Content $lcuPath
$parts = $content -split ":"
$port = $parts[2]
$password = $parts[3]

Write-Host "Port: $port" -ForegroundColor Cyan

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("riot:$password"))

Write-Host "`n[Diagnostic] Checking basic connection..." -ForegroundColor Yellow
$testUrl = "https://127.0.0.1:$port/lol-summoner/v1/current-summoner"
try {
    $testRequest = [System.Net.WebRequest]::Create($testUrl)
    $testRequest.Method = "GET"
    $testRequest.Headers.Add("Authorization", "Basic $auth")
    $testRequest.Timeout = 3000
    $testResponse = $testRequest.GetResponse()
    Write-Host "[OK] Basic connection works" -ForegroundColor Green
    $testResponse.Close()
} catch {
    Write-Host "[ERROR] Cannot connect to basic API: $_" -ForegroundColor Red
    pause
    exit
}

$url = "https://127.0.0.1:$port/lol-inventory/v2/inventory/CHAMPION_SKIN"
Write-Host "`nConnecting to LCU Inventory API..." -ForegroundColor Yellow

try {
    $request = [System.Net.WebRequest]::Create($url)
    $request.Method = "GET"
    $request.Headers.Add("Authorization", "Basic $auth")
    $request.ContentType = "application/json"
    $request.Accept = "application/json"
    $request.Timeout = 5000
    
    $response = $request.GetResponse()
    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    $responseText = $reader.ReadToEnd()
    $reader.Close()
    $response.Close()
    
    [System.IO.File]::WriteAllText("inventory.json", $responseText)
    Write-Host "Raw data saved to inventory.json" -ForegroundColor Green
    
    $skinsData = $responseText | ConvertFrom-Json
    $skinIds = @()
    
    if ($skinsData -is [array]) {
        $skinIds = $skinsData
    } else {
        foreach ($property in $skinsData.PSObject.Properties) {
            if ($property.Value -is [PSCustomObject] -and $property.Value.itemId) {
                $skinIds += $property.Value.itemId
            } elseif ($property.Value -match '^\d+$') {
                $skinIds += $property.Value
            }
        }
    }
    
    $skinIds = $skinIds | Where-Object {$_ -and $_ -ne $null} | Sort-Object -Unique
    
    Write-Host "`nSuccess!" -ForegroundColor Green
    Write-Host "Found $($skinIds.Count) purchased skins" -ForegroundColor White
    Write-Host ""
    Write-Host "Files created:" -ForegroundColor Cyan
    Write-Host "inventory.json (raw data)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Location: $((Get-Location).Path)" -ForegroundColor Gray
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "1. LoL client is not fully loaded (wait a minute and try again)" -ForegroundColor Yellow
    Write-Host "2. You are in game (inventory endpoint may be unavailable during match)" -ForegroundColor Yellow
    Write-Host "3. Network or antivirus issues" -ForegroundColor Yellow
}

pause