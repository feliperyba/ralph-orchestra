# Test just the priority order test
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\test-helpers.ps1"
. "$PSScriptRoot\message-queue.ps1"

Write-Host "=== Testing Concurrent Task Assignment (Priority) ===" -ForegroundColor Cyan

$env = New-TestEnvironment -TestName "priority-test"
Initialize-MessageQueue -SessionDir $env.SessionDir

# PM assigns tasks to multiple agents
$agents = @("developer", "qa", "techartist")

foreach ($agent in $agents) {
    for ($i = 1; $i -le 5; $i++) {
        $priority = if ($i -eq 1) { "high" } else { "normal" }
        Send-AgentMessage -From "pm" -To $agent -Type "task_assign" -Payload @{
            taskId = "$agent-task-$i"
            priority = $priority
        } | Out-Null
    }
}

# Verify each agent got their tasks
foreach ($agent in $agents) {
    $pending = Get-PendingMessages -Agent $agent
    Write-Host "`n${agent}:" -ForegroundColor Gray
    Write-Host "  Count: $($pending.Count)" -ForegroundColor Cyan

    if ($pending.Count -gt 0) {
        Write-Host "  First message priority: $($pending[0].priority)" -ForegroundColor Cyan
        Write-Host "  First message task: $($pending[0].payload.taskId)" -ForegroundColor DarkGray

        $firstIsHigh = $pending[0].priority -eq "high"
        Write-Host "  First is high priority: $firstIsHigh" -ForegroundColor $(if ($firstIsHigh) { "Green" } else { "Red" })
    }
}

& $env.Cleanup
Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
