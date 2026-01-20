$TIMESTAMP = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$MSG_ID = "msg-status-$([DateTimeOffset]::Now.ToUnixTimeSeconds())"

$payload = @{
    id = $MSG_ID
    from = "developer"
    to = "watchdog"
    type = "status_update"
    priority = "low"
    payload = @{
        status = "idle"
        currentTask = "waiting"
        details = "Developer agent ready, waiting for task assignment"
    }
    timestamp = $TIMESTAMP
    status = "pending"
} | ConvertTo-Json -Depth 10

$dir = ".claude/session/messages/watchdog"
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$payload | Out-File -FilePath "$dir/$MSG_ID.json" -Encoding utf8

Write-Host "Status update sent: $MSG_ID"
