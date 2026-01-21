# Ralph Developer Worker Loop
# Runs /ralph-worker with individual context reset

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$agentLoop = Join-Path $scriptDir "agent-loop.ps1"

# Source configuration for max iterations
. "$scriptDir\ralph-config.ps1"
$config = Get-RalphConfig

& $agentLoop -AgentType "developer" -Command "/ralph-worker --agent developer" -MaxIterations $config.MaxIterations
