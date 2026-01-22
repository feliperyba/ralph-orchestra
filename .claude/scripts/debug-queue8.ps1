# Debug test 8 - check .NET EnumerateFiles directly
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Debug Message Queue Test 8 (.NET EnumerateFiles) ===" -ForegroundColor Cyan

$env = New-TestEnvironment -TestName "debug-queue8"
Initialize-MessageQueue -SessionDir $env.SessionDir

# Send a message
$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ test = "debug" }
Write-Host "Message ID: $msgId" -ForegroundColor Green

# Try .NET EnumerateFiles directly
$inbox = Join-Path $Script:MessageQueueDir "developer"
Write-Host "`nDirect .NET EnumerateFiles:" -ForegroundColor Gray
Write-Host "  Path: $inbox" -ForegroundColor DarkGray
Write-Host "  Exists: $([System.IO.Directory]::Exists($inbox))" -ForegroundColor DarkGray

$dirInfo = [System.IO.DirectoryInfo]::new($inbox)
Write-Host "  DirectoryInfo created" -ForegroundColor DarkGray

# Try different filters
Write-Host "`nTrying different filters:" -ForegroundColor Gray

$allFiles = $dirInfo.EnumerateFiles("*", [System.IO.SearchOption]::TopDirectoryOnly)
$allList = @($allFiles)
Write-Host "  Filter '*': $($allList.Count) files" -ForegroundColor Cyan

$jsonFiles = $dirInfo.EnumerateFiles("*.json", [System.IO.SearchOption]::TopDirectoryOnly)
$jsonList = @($jsonFiles)
Write-Host "  Filter '*.json': $($jsonList.Count) files" -ForegroundColor Cyan

# Try Get-ChildItem as comparison
Write-Host "`nGet-ChildItem for comparison:" -ForegroundColor Gray
$psFiles = Get-ChildItem -Path $inbox -Filter "*.json"
Write-Host "  Files: $($psFiles.Count)" -ForegroundColor Cyan

# Cleanup
& $env.Cleanup
Write-Host "`n[OK] Debug 8 complete" -ForegroundColor Green
