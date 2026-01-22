# Debug test 12 - check message content and filters
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Debug Message Round-Trip Test 2 ===" -ForegroundColor Cyan

$env = New-TestEnvironment -TestName "roundtrip-debug2"
Initialize-MessageQueue -SessionDir $env.SessionDir

# Send message
$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ taskId = "test-001" }
Write-Host "Message ID: $msgId" -ForegroundColor Green

# Read file directly
$inbox = Join-Path $Script:MessageQueueDir "developer"
$file = Get-ChildItem -Path $inbox -Filter "*.json"
$content = Get-Content $file.FullName -Raw | ConvertFrom-Json

Write-Host "`nDirect file read:" -ForegroundColor Gray
Write-Host "  id: $($content.id)" -ForegroundColor DarkGray
Write-Host "  type: $($content.type)" -ForegroundColor DarkGray
Write-Host "  status: '$($content.status)'" -ForegroundColor DarkGray
Write-Host "  priority: '$($content.priority)'" -ForegroundColor DarkGray
Write-Host "  payload: $($content.payload | ConvertTo-Json -Compress)" -ForegroundColor DarkGray

# Check filters
Write-Host "`nFilter checks:" -ForegroundColor Gray
Write-Host "  status -eq 'pending': $($content.status -eq 'pending')" -ForegroundColor Cyan

$priorityOrder = @{ "low" = 0; "normal" = 1; "high" = 2; "urgent" = 3 }
$msgPriority = $priorityOrder[$content.priority]
Write-Host "  msgPriority: $msgPriority" -ForegroundColor DarkGray
Write-Host "  msgPriority -ge 0: $($msgPriority -ge 0)" -ForegroundColor Cyan

# Manually trace Get-PendingMessages
Write-Host "`nManual Get-PendingMessages trace:" -ForegroundColor Gray
$allFiles = Get-ChildItem -Path $inbox -Filter "*.json"
Write-Host "  Files: $($allFiles.Count)" -ForegroundColor DarkGray

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$messages = @()
foreach ($fileInfo in $allFiles) {
    Write-Host "  Processing file: $($fileInfo.Name)" -ForegroundColor DarkGray
    $content2 = Get-Content $fileInfo.FullName -Raw | ConvertFrom-Json
    Write-Host "    status: '$($content2.status)'" -ForegroundColor DarkGray
    if ($content2.status -ne "pending") {
        Write-Host "    FILTERED OUT (not pending)" -ForegroundColor Yellow
        continue
    }
    $messages += $content2
    Write-Host "    ADDED" -ForegroundColor Green
}
$stopwatch.Stop()
Write-Host "  Result: $($messages.Count) messages" -ForegroundColor Cyan

# Now call actual Get-PendingMessages
Write-Host "`nActual Get-PendingMessages:" -ForegroundColor Gray
$pending = Get-PendingMessages -Agent "developer"
Write-Host "  Count: $($pending.Count)" -ForegroundColor $(if ($pending.Count -gt 0) { "Green" } else { "Red" })
Write-Host "  Type: $($pending.GetType().Name)" -ForegroundColor DarkGray

# Cleanup
& $env.Cleanup
Write-Host "`n[OK] Debug complete" -ForegroundColor Green
