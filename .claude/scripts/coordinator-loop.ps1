# Ralph Coordinator Loop (PM Agent)
# Runs /ralph-coordinator with individual context reset

Write-Host "=== coordinator-loop.ps1 STARTED ===" -ForegroundColor Magenta

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$agentLoop = Join-Path $scriptDir "agent-loop.ps1"

Write-Host "scriptDir: $scriptDir" -ForegroundColor Yellow
Write-Host "agentLoop: $agentLoop" -ForegroundColor Yellow
Write-Host "File exists: $(Test-Path $agentLoop)" -ForegroundColor Yellow
Write-Host "Calling agent-loop.ps1..." -ForegroundColor Yellow

& $agentLoop -AgentType "coordinator" -Command "/ralph-coordinator" -MaxIterations 50

Write-Host "=== coordinator-loop.ps1 ENDED ===" -ForegroundColor Magenta
