# Debug test 10 - trace through Get-ChildItemWithTimeout manually
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\safe-file-io.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Debug Message Queue Test 10 (Manual Trace) ===" -ForegroundColor Cyan

$env = New-TestEnvironment -TestName "debug-queue10"
Initialize-MessageQueue -SessionDir $env.SessionDir

# Send a message
$msgId = Send-AgentMessage -From "pm" -To "developer" -Type "task_assign" -Payload @{ test = "debug" }
Write-Host "Message ID: $msgId" -ForegroundColor Green

# Manually replicate Get-ChildItemWithTimeout logic
$inbox = Join-Path $Script:MessageQueueDir "developer"
Write-Host "`nManual trace of Get-ChildItemWithTimeout:" -ForegroundColor Gray

# Step 1: Check if directory exists
Write-Host "1. Directory exists: $([System.IO.Directory]::Exists($inbox))" -ForegroundColor DarkGray

# Step 2: Create DirectoryInfo
$dirInfo = [System.IO.DirectoryInfo]::new($inbox)
Write-Host "2. DirectoryInfo created" -ForegroundColor DarkGray

# Step 3: Enumerate files
$Filter = "*.json"
$enumOptions = [System.IO.EnumerationOptions]::new()
$enumOptions.IgnoreInaccessible = $true
$enumOptions.ReturnSpecialDirectories = $false
$enumOptions.RecurseSubdirectories = $false

$fileInfos = $dirInfo.EnumerateFiles($Filter, [System.IO.SearchOption]::TopDirectoryOnly)
Write-Host "3. EnumerateFiles called" -ForegroundColor DarkGray

# Step 4: Force enumeration
$result = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$enumeratedCount = 0

foreach ($fileInfo in $fileInfos) {
    Write-Host "   Found file: $($fileInfo.Name) at $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor DarkGray
    if ($stopwatch.ElapsedMilliseconds -gt 10000) {
        Write-Host "   TIMEOUT!" -ForegroundColor Red
        break
    }
    $result.Add($fileInfo)
    $enumeratedCount++
}
$stopwatch.Stop()
Write-Host "4. Enumerated $enumeratedCount files" -ForegroundColor DarkGray

# Step 5: Convert to PSCustomObject
$output = @($result | ForEach-Object {
    [PSCustomObject]@{
        FullName = $_.FullName
        Name = $_.Name
        Extension = $_.Extension
        Length = $_.Length
        LastWriteTime = $_.LastWriteTime
        LastWriteTimeUtc = $_.LastWriteTimeUtc
        PSIsContainer = $false
    }
})
Write-Host "5. Converted to $($output.Count) PSCustomObjects" -ForegroundColor DarkGray

# Step 6: Check what we got
if ($output.Count -gt 0) {
    foreach ($o in $output) {
        Write-Host "   Object: Name=$($o.Name), FullName=$($o.FullName)" -ForegroundColor DarkGray
    }
}

# Now actually call the function
Write-Host "`nCalling actual Get-ChildItemWithTimeout:" -ForegroundColor Gray
$actualResult = Get-ChildItemWithTimeout -Path $inbox -Filter "*.json" -TimeoutMs 10000
Write-Host "Result: $($actualResult.Count) files" -ForegroundColor $(if ($actualResult.Count -gt 0) { "Green" } else { "Red" })

# Cleanup
& $env.Cleanup
Write-Host "`n[OK] Debug 10 complete" -ForegroundColor Green
