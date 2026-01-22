# Debug test 3 - deeper investigation
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Debug Message Queue Test 3 ===" -ForegroundColor Cyan

$env = New-TestEnvironment -TestName "debug-queue3"
Initialize-MessageQueue -SessionDir $env.SessionDir

# Send a message
$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ test = "debug" }
Write-Host "Message ID: $msgId" -ForegroundColor Green

# Check file directly
$inbox = Join-Path $Script:MessageQueueDir "developer"
$file = Get-ChildItem $inbox -Filter "*.json"

# Manually read and parse
$rawContent = Get-Content $file.FullName -Raw
Write-Host "`nRaw content: $($rawContent.Substring(0, [Math]::Min(200, $rawContent.Length)))..." -ForegroundColor Gray

$parsed = $rawContent | ConvertFrom-Json
Write-Host "`nParsed status: '$($parsed.status)'" -ForegroundColor Gray
Write-Host "Parsed type: '$($parsed.type)'" -ForegroundColor Gray
Write-Host "Parsed priority: '$($parsed.priority)'" -ForegroundColor Gray

# Check each filter condition
Write-Host "`nFilter checks:" -ForegroundColor Gray
Write-Host "  status -eq 'pending': $($parsed.status -eq 'pending')" -ForegroundColor Cyan
Write-Host "  type -eq 'task_assign': $($parsed.type -eq 'task_assign')" -ForegroundColor Cyan
Write-Host "  priority is valid: $($parsed.priority -in @('low','normal','high','urgent'))" -ForegroundColor Cyan

# Try the actual function with tracing
Write-Host "`nCalling Get-PendingMessages with 5000ms timeout:" -ForegroundColor Gray
$pending = Get-PendingMessages -Agent "developer" -TimeoutMs 5000
Write-Host "Result count: $($pending.Count)" -ForegroundColor $(if ($pending.Count -gt 0) { "Green" } else { "Red" })

# Check if the messages array is being populated
Write-Host "`nChecking messages directly from file:" -ForegroundColor Gray
$allFiles = Get-ChildItem -Path $inbox -Filter "*.json"
Write-Host "Files found: $($allFiles.Count)" -ForegroundColor Gray

foreach ($fileInfo in $allFiles) {
    $content = Read-MessageFileWithRetry -FilePath $fileInfo.FullName -TimeoutMs 5000
    Write-Host "  File: $($fileInfo.Name)" -ForegroundColor DarkGray
    Write-Host "    Content: " -NoNewline -ForegroundColor DarkGray
    if ($content) {
        Write-Host "id=$($content.id), status=$($content.status), type=$($content.type)" -ForegroundColor DarkGray
    } else {
        Write-Host "NULL" -ForegroundColor Red
    }
}

# Cleanup
& $env.Cleanup
Write-Host "`n[OK] Debug 3 complete" -ForegroundColor Green
