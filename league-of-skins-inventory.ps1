# get_my_skins_diagnostic.ps1
Write-Host "League of Legends Inventory Diagnostic" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

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
    pause
    exit
}

$content = Get-Content $lcuPath
$parts = $content -split ":"
$port = $parts[2]
$password = $parts[3]

Write-Host "Port: $port" -ForegroundColor Cyan

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("riot:$password"))

Write-Host "`nTesting basic endpoints..." -ForegroundColor Yellow

$basicEndpoints = @(
    "/lol-summoner/v1/current-summoner",
    "/lol-chat/v1/me",
    "/lol-platform-config/v1/namespaces"
)

foreach ($endpoint in $basicEndpoints) {
    $url = "https://127.0.0.1:$port$endpoint"
    try {
        $request = [System.Net.WebRequest]::Create($url)
        $request.Method = "GET"
        $request.Headers.Add("Authorization", "Basic $auth")
        $request.Timeout = 2000
        $response = $request.GetResponse()
        $statusCode = $response.StatusCode
        $response.Close()
        Write-Host "  OK - $endpoint - $statusCode" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            Write-Host "  FAIL - $endpoint - $statusCode" -ForegroundColor Red
        }
        else {
            Write-Host "  FAIL - $endpoint - Connection error" -ForegroundColor Red
        }
    }
}

Write-Host "`nTesting skin inventory endpoints..." -ForegroundColor Yellow

$skinEndpoints = @(
    "/lol-inventory/v2/inventory/CHAMPION_SKIN",
    "/lol-inventory/v1/inventory/CHAMPION_SKIN",
    "/lol-inventory/v1/inventory/CHAMPION_SKIN_OWNED",
    "/lol-collections/v1/inventories/1/skins",
    "/lol-collections/v1/inventories/1/skins-minimal",
    "/lol-champions/v1/inventories/1/skins",
    "/lol-champions/v1/inventories/1/skins-minimal",
    "/lol-skins/v1/skins",
    "/lol-skins/v1/inventory",
    "/lol-skins/v1/skins-owned",
    "/lol-store/v1/entitlements/CHAMPION_SKIN",
    "/lol-store/v1/entitlements?itemType=CHAMPION_SKIN"
)

$workingEndpoints = @()

foreach ($endpoint in $skinEndpoints) {
    $url = "https://127.0.0.1:$port$endpoint"
    Write-Host "Testing: $endpoint" -NoNewline
    
    try {
        $request = [System.Net.WebRequest]::Create($url)
        $request.Method = "GET"
        $request.Headers.Add("Authorization", "Basic $auth")
        $request.Timeout = 2000
        
        $response = $request.GetResponse()
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $responseText = $reader.ReadToEnd()
        $reader.Close()
        $response.Close()
        
        $size = $responseText.Length
        Write-Host " - OK (200) - $size bytes" -ForegroundColor Green
        
        if ($size -gt 10) {
            $workingEndpoints += $endpoint
            if ($workingEndpoints.Count -eq 1) {
                [System.IO.File]::WriteAllText("inventory.json", $responseText)
                Write-Host "  -> Saved to inventory.json" -ForegroundColor Yellow
            }
        }
    }
    catch {
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            Write-Host " - FAIL ($statusCode)" -ForegroundColor Red
        }
        else {
            Write-Host " - ERROR" -ForegroundColor Red
        }
    }
}

if ($workingEndpoints.Count -gt 0) {
    Write-Host "`nWorking endpoints found:" -ForegroundColor Green
    foreach ($ep in $workingEndpoints) {
        Write-Host "  $ep" -ForegroundColor Cyan
    }
    Write-Host "`nData saved to inventory.json" -ForegroundColor Green
}
else {
    Write-Host "`nNo working skin inventory endpoints found" -ForegroundColor Red
    
    Write-Host "`nTrying to get API documentation..." -ForegroundColor Yellow
    $swaggerUrl = "https://127.0.0.1:$port/swagger/v2/swagger.json"
    try {
        $request = [System.Net.WebRequest]::Create($swaggerUrl)
        $request.Method = "GET"
        $request.Headers.Add("Authorization", "Basic $auth")
        $request.Timeout = 2000
        $response = $request.GetResponse()
        Write-Host "Swagger documentation available" -ForegroundColor Green
        $response.Close()
    }
    catch {
        Write-Host "No swagger documentation" -ForegroundColor Red
    }
}

pause