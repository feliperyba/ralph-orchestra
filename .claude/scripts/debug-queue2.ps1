# Debug test 2 - check message file content
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Debug Message Queue Test 2 ===" -ForegroundColor Cyan

$env = New-TestEnvironment -TestName "debug-queue2"
Initialize-MessageQueue -SessionDir $env.SessionDir

# Send a message
$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ test = "debug" }
Write-Host "Message ID: $msgId" -ForegroundColor Green

# Find and read the file directly
$inbox = Join-Path $Script:MessageQueueDir "developer"
$files = Get-ChildItem $inbox -Filter "*.json"
Write-Host "`nFiles found: $($files.Count)" -ForegroundColor Gray

foreach ($file in $files) {
    Write-Host "`nFile: $($file.Name)" -ForegroundColor Gray
    Write-Host "Content:" -ForegroundColor Gray
    $content = Get-Content $file.FullName -Raw
    Write-Host $content -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Parsed:" -ForegroundColor Gray
    $parsed = $content | ConvertFrom-Json
    Write-Host "  id: $($parsed.id)" -ForegroundColor DarkGray
    Write-Host "  type: $($parsed.type)" -ForegroundColor DarkGray
    Write-Host "  status: $($parsed.status)" -ForegroundColor DarkGray
    Write-Host "  from: $($parsed.from)" -ForegroundColor DarkGray
    Write-Host "  to: $($parsed.to)" -ForegroundColor DarkGray
}

# Now try Get-PendingMessages
Write-Host "`nGet-PendingMessages:" -ForegroundColor Gray
$pending = Get-PendingMessages -Agent "developer"
Write-Host "Result: $($pending.Count) messages" -ForegroundColor $(if ($pending.Count -gt 0) { "Green" } else { "Red" })

# Check if Read-MessageFileWithRetry works
Write-Host "`nChecking Read-MessageFileWithRetry:" -ForegroundColor Gray
if (Get-Command Read-MessageFileWithRetry -ErrorAction SilentlyContinue) {
    $result = Read-MessageFileWithRetry -FilePath $files[0].FullName -TimeoutMs 5000
    Write-Host "Result: " -NoNewline
    if ($result) {
        Write-Host $result -ForegroundColor DarkGray
    } else {
        Write-Host "NULL or empty" -ForegroundColor Red
    }
} else {
    Write-Host "Read-MessageFileWithRetry command not found!" -ForegroundColor Red
}

# Cleanup
& $env.Cleanup
Write-Host "`n[OK] Debug 2 complete" -ForegroundColor Green
