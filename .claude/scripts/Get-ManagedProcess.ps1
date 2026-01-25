<#
.SYNOPSIS
    Manages process lifecycle for Ralph agents

.DESCRIPTION
    Provides functions to check, start, track, and cleanup processes.
    Prevents duplicate processes and ensures cleanup on exit.

    USAGE:
        # Check if dev server is running
        $server = .\Get-ManagedProcess.ps1 -Name "dev-server" -Port 3000

        # Start if not running
        if (-not $server) {
            $server = .\Get-ManagedProcess.ps1 -Name "dev-server" -Port 3000 -Command "npm run dev:all:sh" -Agent "qa"
        }

        # Cleanup on exit
        .\Stop-ManagedProcess.ps1 -Agent "qa"

.PARAMETER Name
    The process name (e.g., "dev-server", "test-runner")

.PARAMETER Port
    The port number the process uses (e.g., 3000, 6006)

.PARAMETER Command
    The command to start the process (only used when starting)

.PARAMETER Agent
    The agent name (pm, developer, qa)

.PARAMETER Purpose
    Why this process is being started (e.g., "browser-validation", "test-watch")

.EXAMPLE
    .\Get-ManagedProcess.ps1 -Name "dev-server" -Port 3000

.EXAMPLE
    .\Get-ManagedProcess.ps1 -Name "dev-server" -Port 3000 -Command "npm run dev:all:sh" -Agent "qa" -Purpose "browser-validation"
#>

[CmdletBinding(DefaultParameterSetName = "Check")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Check")]
    [Parameter(Mandatory = $true, ParameterSetName = "Start")]
    [string]$Name,

    [Parameter(Mandatory = $false, ParameterSetName = "Check")]
    [Parameter(Mandatory = $true, ParameterSetName = "Start")]
    [int]$Port,

    [Parameter(Mandatory = $true, ParameterSetName = "Start")]
    [string]$Command,

    [Parameter(Mandatory = $true, ParameterSetName = "Start")]
    [ValidateSet("pm", "developer", "qa")]
    [string]$Agent,

    [Parameter(Mandatory = $false, ParameterSetName = "Start")]
    [string]$Purpose = "general"
)

# Registry file path
$RegistryPath = Join-Path $PSScriptRoot "..\session\process-registry.json"

# Ensure session directory exists
$SessionDir = Split-Path $RegistryPath -Parent
if (-not (Test-Path $SessionDir)) {
    New-Item -ItemType Directory -Path $SessionDir -Force | Out-Null
}

# Initialize registry if it doesn't exist
function Initialize-Registry {
    if (-not (Test-Path $RegistryPath)) {
        $emptyRegistry = @{
            version = "1.0"
            lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
            processes = @{}
            agents = @{
                pm = @()
                developer = @()
                qa = @()
            }
        }
        $emptyRegistry | ConvertTo-Json -Depth 10 | Set-Content $RegistryPath
    }
}

# Read registry
function Get-Registry {
    Initialize-Registry
    $content = Get-Content $RegistryPath -Raw
    return $content | ConvertFrom-Json
}

# Write registry atomically
function Set-Registry {
    param([PSCustomObject]$Registry)

    # Convert to hashtable for proper JSON serialization
    $processesHash = @{}
    if ($Registry.processes) {
        foreach ($prop in $Registry.processes.PSObject.Properties) {
            $processesHash[$prop.Name] = @{
                name = $prop.Value.name
                port = $prop.Value.port
                pid = $prop.Value.pid
                agent = $prop.Value.agent
                startedAt = $prop.Value.startedAt
                command = $prop.Value.command
                status = $prop.Value.status
                purpose = $prop.Value.purpose
            }
        }
    }

    $agentsHash = @{
        pm = if ($Registry.agents.pm) { @($Registry.agents.pm) } else { @() }
        developer = if ($Registry.agents.developer) { @($Registry.agents.developer) } else { @() }
        qa = if ($Registry.agents.qa) { @($Registry.agents.qa) } else { @() }
    }

    $outputRegistry = @{
        version = "1.0"
        lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
        processes = $processesHash
        agents = $agentsHash
    }

    $TempPath = "$RegistryPath.tmp"
    $outputRegistry | ConvertTo-Json -Depth 10 | Set-Content $TempPath
    Move-Item -Path $TempPath -Destination $RegistryPath -Force
}

# Generate process key
function Get-ProcessKey {
    param([string]$Name, [int]$Port)
    if ($Port -gt 0) {
        return "$Name-$Port"
    }
    return $Name
}

# Check if port is in use
function Test-PortInUse {
    param([int]$Port)

    try {
        $connection = New-Object System.Net.Sockets.TcpClient
        $connect = $connection.BeginConnect("127.0.0.1", $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(500, $false)

        if ($wait) {
            try {
                $connection.EndConnect($connect)
                $connection.Close()
                return $true
            } catch {
                return $false
            }
        }
        return $false
    } catch {
        return $false
    }
}

# Get process by port
function Get-ProcessByPort {
    param([int]$Port)

    try {
        $netstat = netstat -ano | Select-String ":$Port\s" | Select-String "LISTENING"
        if ($netstat) {
            $procId = ($netstat -split '\s+')[-1]
            return Get-Process -Id $procId -ErrorAction SilentlyContinue
        }
    } catch {
        return $null
    }
    return $null
}

# Check if process is alive
function Test-ProcessAlive {
    param([int]$ProcId)

    try {
        $process = Get-Process -Id $ProcId -ErrorAction SilentlyContinue
        return $null -ne $process
    } catch {
        return $false
    }
}

# Cleanup dead processes from registry
function Remove-DeadProcesses {
    $registry = Get-Registry
    $deadProcesses = @()

    if ($registry.processes) {
        foreach ($key in $registry.processes.PSObject.Properties.Name) {
            $processInfo = $registry.processes.$key
            if (-not (Test-ProcessAlive -ProcId $processInfo.pid)) {
                $deadProcesses += $key
            }
        }
    }

    if ($deadProcesses.Count -gt 0) {
        foreach ($key in $deadProcesses) {
            $processInfo = $registry.processes.$key
            $agent = $processInfo.agent
            $registry.processes.PSObject.Properties.Remove($key)
            if ($registry.agents.$agent) {
                $registry.agents.$agent = @($registry.agents.$agent | Where-Object { $_ -ne $key })
            }
        }
        Set-Registry $registry
    }
}

# Check for existing process
function Get-ManagedProcess {
    $registry = Get-Registry
    Remove-DeadProcesses

    $key = Get-ProcessKey -Name $Name -Port $Port

    if ($registry.processes -and $registry.processes.PSObject.Properties.Name -contains $key) {
        $processInfo = $registry.processes.$key

        # Verify process is actually running
        if (Test-ProcessAlive -ProcId $processInfo.pid) {
            # If port specified, verify port is accessible
            if ($Port -gt 0) {
                if (Test-PortInUse -Port $Port) {
                    return $processInfo
                } else {
                    # Process exists but port not accessible - mark as dead
                    Write-Warning "Process $($processInfo.pid) exists but port $Port is not accessible"
                    return $null
                }
            }
            return $processInfo
        }
    }

    return $null
}

# Start a new managed process
function Start-ManagedProcess {
    $registry = Get-Registry
    $key = Get-ProcessKey -Name $Name -Port $Port

    # Check port first if specified
    if ($Port -gt 0) {
        $existingProcess = Get-ProcessByPort -Port $Port
        if ($existingProcess) {
            Write-Warning "Port $Port is already in use by PID $($existingProcess.Id)"
            return $null
        }
    }

    # Create process info
    $processInfo = [PSCustomObject]@{
        name = $Name
        port = if ($Port -gt 0) { $Port } else { $null }
        pid = $null
        agent = $Agent
        startedAt = (Get-Date).ToUniversalTime().ToString("o")
        command = $Command
        status = "starting"
        purpose = $Purpose
    }

    try {
        # Start process in background
        $process = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile", "-Command", $Command -PassThru -WindowStyle Hidden
        $processInfo.pid = $process.Id
        $processInfo.status = "running"

        # Wait a bit for process to start
        Start-Sleep -Seconds 2

        # Verify process is still running
        if (Test-ProcessAlive -ProcId $processInfo.pid) {
            # Add to registry processes
            if (-not $registry.processes) {
                $registry | Add-Member -NotePropertyName "processes" -NotePropertyValue (New-Object PSCustomObject) -Force
            }
            $registry.processes | Add-Member -NotePropertyName $key -NotePropertyValue $processInfo -Force

            # Add to agent's list
            if (-not $registry.agents.$Agent) {
                $registry.agents | Add-Member -NotePropertyName $Agent -NotePropertyValue @() -Force
            }
            $agentList = @($registry.agents.$Agent)
            if ($agentList -notcontains $key) {
                $agentList += $key
                $registry.agents.$Agent = $agentList
            }

            Set-Registry $registry

            Write-Host "Started managed process '$Name' (PID: $($processInfo.pid), Port: $Port)"

            return $processInfo
        } else {
            Write-Error "Process failed to start or died immediately"
            return $null
        }
    } catch {
        Write-Error "Failed to start process: $_"
        return $null
    }
}

# Main logic
if ($PSCmdlet.ParameterSetName -eq "Check") {
    $result = Get-ManagedProcess
    if ($result) {
        Write-Host "Found existing process '$Name' (PID: $($result.pid))"
        return $result
    } else {
        Write-Host "No existing process '$Name' found"
        return $null
    }
} elseif ($PSCmdlet.ParameterSetName -eq "Start") {
    # First check if already exists
    $existing = Get-ManagedProcess
    if ($existing) {
        Write-Host "Process '$Name' already running (PID: $($existing.pid))"
        return $existing
    }

    # Start new process
    return Start-ManagedProcess
}
