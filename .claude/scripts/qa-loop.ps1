# Ralph QA Worker Loop
# Runs /ralph-worker with individual context reset

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$agentLoop = Join-Path $scriptDir "agent-loop.ps1"

& $agentLoop -AgentType "qa" -Command "/ralph-worker --agent qa" -MaxIterations 50
