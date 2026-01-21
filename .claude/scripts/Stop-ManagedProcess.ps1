<#
.SYNOPSIS
    Stops all processes owned by an agent

.DESCRIPTION
    Stops all registered processes for a specific agent and removes them
    from the process registry. Use this to cleanup before going idle.

.PARAMETER Agent
    The agent name (pm, developer, qa)

.PARAMETER Name
    Optional: Stop a specific process by name instead of all agent processes

.PARAMETER Force
    Force kill processes even if they don't shut down gracefully

.EXAMPLE
    Stop-ManagedProcess -Agent "qa"

.EXAMPLE
    Stop-ManagedProcess -Name "dev-server-3000"

.EXAMPLE
    Stop-ManagedProcess -Agent "qa" -Force
#>

[CmdletBinding(DefaultParameterSetName = "Agent")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Agent", Position = 0)]
    [ValidateSet("pm", "developer", "qa")]
    [string]$Agent,

    [Parameter(Mandatory = $true, ParameterSetName = "Name", Position = 0)]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Registry file path
$RegistryPath = Join-Path $PSScriptRoot "..\session\process-registry.json"

# Read registry
function Get-Registry {
    if (Test-Path $RegistryPath) {
        return Get-Content $RegistryPath | ConvertFrom-Json
    }
    return $null
}

# Write registry atomically
function Set-Registry {
    param([hashtable]$Registry)
    $Registry.lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
    $TempPath = "$RegistryPath.tmp"
    $Registry | ConvertTo-Json -Depth 10 | Set-Content $TempPath
    Move-Item -Path $TempPath -Destination $RegistryPath -Force
}

# Stop a single process
function Stop-ProcessEntry {
    param([PSCustomObject]$ProcessInfo, [string]$Key, [switch]$ForceKill)

    $stopped = $false

    try {
        # Try to get the process
        $process = Get-Process -Id $ProcessInfo.pid -ErrorAction SilentlyContinue

        if ($process) {
            Write-Host "Stopping process '$($ProcessInfo.name)' (PID: $($ProcessInfo.pid), Port: $($ProcessInfo.port))"

            if ($ForceKill) {
                # Force kill
                $process.Kill()
                $stopped = $true
            } else {
                # Try graceful shutdown first
                $process.CloseMainWindow() | Out-Null

                # Wait up to 5 seconds for graceful shutdown
                $timeout = 5000
                $hasExited = $process.WaitForExit($timeout)

                if ($hasExited) {
                    Write-Host "  Process exited gracefully"
                    $stopped = $true
                } else {
                    # Force kill if graceful didn't work
                    Write-Warning "  Process did not exit gracefully, forcing..."
                    $process.Kill()
                    $stopped = $true
                }
            }
        } else {
            Write-Host "  Process $($ProcessInfo.pid) already stopped (not running)"
            $stopped = $true
        }
    } catch {
        Write-Warning "  Error stopping process $($ProcessInfo.pid): $_"
        # Consider it stopped if we can't manage it
        $stopped = $true
    }

    return $stopped
}

# Main logic
$registry = Get-Registry

if (-not $registry) {
    Write-Host "No process registry found"
    return
}

$processesToStop = @()
$keysToRemove = @()

if ($PSCmdlet.ParameterSetName -eq "Agent") {
    # Get all processes for this agent
    $agentProcesses = $registry.agents.$Agent

    if ($agentProcesses -and $agentProcesses.Count -gt 0) {
        foreach ($key in $agentProcesses) {
            if ($registry.processes.PSObject.Properties.Name -contains $key) {
                $processesToStop += @{
                    Key = $key
                    Info = $registry.processes.$key
                }
                $keysToRemove += $key
            }
        }
    } else {
        Write-Host "No processes found for agent '$Agent'"
        return
    }
} elseif ($PSCmdlet.ParameterSetName -eq "Name") {
    # Stop specific process by name
    if ($registry.processes.PSObject.Properties.Name -contains $Name) {
        $processesToStop += @{
            Key = $Name
            Info = $registry.processes.$Name
        }
        $keysToRemove += $Name
    } else {
        Write-Host "Process '$Name' not found in registry"
        return
    }
}

# Stop all identified processes
$stoppedCount = 0
foreach ($entry in $processesToStop) {
    if (Stop-ProcessEntry -ProcessInfo $entry.Info -Key $entry.Key -ForceKill:$Force) {
        $stoppedCount++
    }
}

# Remove from registry
$registryObj = @{
    version = $registry.version
    lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
    processes = @{}
    agents = @{
        pm = @($registry.agents.pm)
        developer = @($registry.agents.developer)
        qa = @($registry.agents.qa)
    }
}

# Copy non-removed processes
foreach ($key in $registry.processes.PSObject.Properties.Name) {
    if ($keysToRemove -notcontains $key) {
        $registryObj.processes[$key] = $registry.processes.$key
    }
}

# Remove keys from agent lists
foreach ($agent in @("pm", "developer", "qa")) {
    $registryObj.agents[$agent] = @($registry.agents.$agent | Where-Object { $keysToRemove -notcontains $_ })
}

# Write updated registry
Set-Registry $registryObj

Write-Host "Stopped $stoppedCount process(es), updated registry"
