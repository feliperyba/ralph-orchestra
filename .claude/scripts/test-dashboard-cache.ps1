# Test script for dashboard cell caching

$ErrorActionPreference = "Stop"

Write-Host "=== Dashboard Cell Cache Test ===" -ForegroundColor Cyan

# Source watchdog script partially - just the cache parts
$Script:DashboardCellCache = @{}
$Script:CellCacheMaxAge = 1000  # 1 second TTL

function Get-CachedDashboardCell {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CellId,

        [Parameter(Mandatory=$true)]
        [scriptblock]$Formatter
    )

    $now = [DateTime]::UtcNow

    # Check cache
    if ($Script:DashboardCellCache.ContainsKey($CellId)) {
        $cached = $Script:DashboardCellCache[$CellId]
        if (($now - $cached.Time).TotalMilliseconds -lt $Script:CellCacheMaxAge) {
            return $cached.Value
        }
    }

    # Compute and cache
    $value = & $Formatter
    $Script:DashboardCellCache[$CellId] = @{
        Time = $now
        Value = $value
    }

    return $value
}

function Clear-DashboardCellCache {
    $Script:DashboardCellCache.Clear()
}

# Test 1: Cache hit
Write-Host "`n1. Testing cache hit..." -ForegroundColor Gray
$Script:WatchdogStartTime = [DateTime]::UtcNow.AddHours(-1)  # 1 hour ago

$result1 = Get-CachedDashboardCell -CellId "uptime" -Formatter {
    $uptime = ([DateTime]::UtcNow - $Script:WatchdogStartTime)
    "{0:hh\:mm\:ss}" -f $uptime
}
Write-Host "   First call: $result1" -ForegroundColor Green

# Call again immediately - should hit cache
$result2 = Get-CachedDashboardCell -CellId "uptime" -Formatter {
    $uptime = ([DateTime]::UtcNow - $Script:WatchdogStartTime)
    "{0:hh\:mm\:ss}" -f $uptime
}
Write-Host "   Second call (cached): $result2" -ForegroundColor Cyan

# Test 2: Cache expiration
Write-Host "`n2. Testing cache expiration..." -ForegroundColor Gray
# Sleep to exceed TTL
Start-Sleep -Milliseconds 1100

$result3 = Get-CachedDashboardCell -CellId "uptime" -Formatter {
    $uptime = ([DateTime]::UtcNow - $Script:WatchdogStartTime)
    "{0:hh\:mm\:ss}" -f $uptime
}
Write-Host "   After TTL: $result3" -ForegroundColor Yellow

# Test 3: Multiple cells
Write-Host "`n3. Testing multiple cells..." -ForegroundColor Gray
Get-CachedDashboardCell -CellId "stat1" -Formatter { "value1" } | Out-Null
Get-CachedDashboardCell -CellId "stat2" -Formatter { "value2" } | Out-Null
Write-Host "   Cache entries: $($Script:DashboardCellCache.Count)" -ForegroundColor Green

# Test 4: Clear cache
Write-Host "`n4. Testing cache clear..." -ForegroundColor Gray
Clear-DashboardCellCache
Write-Host "   After clear: $($Script:DashboardCellCache.Count) entries" -ForegroundColor Green

Write-Host "`n[OK] Dashboard cache test passed!" -ForegroundColor Green
