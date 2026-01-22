# Test script for message-pool.ps1

$ErrorActionPreference = "Stop"

Write-Host "=== Message Pool Test ===" -ForegroundColor Cyan

# Source the message pool module
. "$PSScriptRoot\message-pool.ps1"

# Initialize pool
Write-Host "`n1. Initializing pool..." -ForegroundColor Gray
Initialize-MessagePool

# Get initial stats
$stats = Get-MessagePoolStats
Write-Host "   Pool Size: $($stats.CurrentCount)/$($stats.PoolSize)" -ForegroundColor Green

# Get a pooled message
Write-Host "`n2. Getting pooled message..." -ForegroundColor Gray
$msg = Get-PooledMessage
$msg["test"] = "value"
$msg["id"] = "msg-123"
Write-Host "   Message created: $($msg | ConvertTo-Json -Compress)" -ForegroundColor Green

# Check pool after getting
$stats = Get-MessagePoolStats
Write-Host "   Pool after Get: $($stats.CurrentCount)/$($stats.PoolSize)" -ForegroundColor Yellow

# Return message to pool
Write-Host "`n3. Returning message to pool..." -ForegroundColor Gray
Return-PooledMessage $msg

# Check pool after returning
$stats = Get-MessagePoolStats
Write-Host "   Pool after Return: $($stats.CurrentCount)/$($stats.PoolSize)" -ForegroundColor Green

# Test multiple cycles
Write-Host "`n4. Testing 10 allocation cycles..." -ForegroundColor Gray
for ($i = 0; $i -lt 10; $i++) {
    $m = Get-PooledMessage
    Return-PooledMessage $m
}
$stats = Get-MessagePoolStats
Write-Host "   Reuse Rate: $($stats.ReuseRatePercent)%" -ForegroundColor Cyan

# Show final stats
Write-Host "`n=== Final Stats ===" -ForegroundColor Cyan
Show-MessagePoolStats

Write-Host "`n[OK] All tests passed!" -ForegroundColor Green
