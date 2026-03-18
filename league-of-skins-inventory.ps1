Write-Host "Getting your purchased skins..." -ForegroundColor Cyan

$possiblePaths = @(
    "C:\Riot Games\League of Legends\lockfile",
    "D:\Riot Games\League of Legends\lockfile",
    "E:\Riot Games\League of Legends\lockfile",
    "F:\Riot Games\League of Legends\lockfile",
    "$env:USERPROFILE\AppData\Local\Riot Games\League of Legends\Config\lockfile",
    "$env:USERPROFILE\AppData\Local\Riot Games\Riot Client\Config\lockfile"
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
$url = "https://127.0.0.1:$port/lol-inventory/v2/inventory/CHAMPION_SKIN"

Write-Host "`nConnecting to LCU..." -ForegroundColor Yellow

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
    
    # Сохраняем сырые данные
    [System.IO.File]::WriteAllText("inventory.json", $responseText)
    Write-Host "Raw data saved to inventory.json" -ForegroundColor Green
    
    # Конвертируем JSON
    $skinsData = $responseText | ConvertFrom-Json
    
    # Получаем все ID скинов
    $skinIds = @()
    
    if ($skinsData -is [array]) {
        $skinIds = $skinsData
    } else {
        foreach ($property in $skinsData.PSObject.Properties) {
            # Проверяем, что значение - это объект со свойством itemId
            if ($property.Value -is [PSCustomObject] -and $property.Value.itemId) {
                $skinIds += $property.Value.itemId
            }
            # Или просто добавляем значение, если оно число
            elseif ($property.Value -match '^\d+$') {
                $skinIds += $property.Value
            }
        }
    }
    
    # Убираем дубликаты, null и сортируем
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
}
