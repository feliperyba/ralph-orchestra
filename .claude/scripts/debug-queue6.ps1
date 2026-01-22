# Debug test 6 - check Get-ChildItemWithTimeout directly
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\safe-file-io.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Debug Message Queue Test 6 (Direct Call) ===" -ForegroundColor Cyan

$env = New-TestEnvironment -TestName "debug-queue6"
Initialize-MessageQueue -SessionDir $env.SessionDir

# Send a message
$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ test = "debug" }
Write-Host "Message ID: $msgId" -ForegroundColor Green

# Clear cache
$Script:DirectoryEnumCache.Clear()

# Call Get-ChildItemWithTimeout directly
$inbox = Join-Path $Script:MessageQueueDir "developer"
Write-Host "`nCalling Get-ChildItemWithTimeout directly:" -ForegroundColor Gray
Write-Host "  Inbox path: $inbox" -ForegroundColor DarkGray
Write-Host "  Inbox exists: $(Test-Path $inbox)" -ForegroundColor DarkGray

$files = Get-ChildItemWithTimeout -Path $inbox -Filter "*.json" -TimeoutMs 5000
Write-Host "  Files returned: $($files.Count)" -ForegroundColor $(if ($files.Count -gt 0) { "Green" } else { "Red" })

if ($files.Count -gt 0) {
    foreach ($f in $files) {
        Write-Host "    File: $($f.Name)" -ForegroundColor DarkGray
        Write-Host "      FullName: $($f.FullName)" -ForegroundColor DarkGray
    }
}

# Now try Read-MessageFileWithRetry on each file
Write-Host "`nReading each file:" -ForegroundColor Gray
foreach ($file in $files) {
    Write-Host "  File: $($file.Name)" -ForegroundColor DarkGray
    $content = Read-MessageFileWithRetry -FilePath $file.FullName -TimeoutMs 5000
    if ($content) {
        Write-Host "    Content: id=$($content.id), status=$($content.status)" -ForegroundColor DarkGray
    } else {
        Write-Host "    Content: NULL" -ForegroundColor Red
    }
}

# Cleanup
& $env.Cleanup
Write-Host "`n[OK] Debug 6 complete" -ForegroundColor Green
