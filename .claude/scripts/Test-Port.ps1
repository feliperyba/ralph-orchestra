<#
.SYNOPSIS
    Tests if a port is in use

.DESCRIPTION
    Checks if a specific TCP port is currently in use on localhost.
    Returns true if the port is in use, false otherwise.

.PARAMETER Port
    The port number to test (e.g., 3000, 6006)

.PARAMETER Timeout
    Connection timeout in milliseconds (default: 500)

.EXAMPLE
    Test-Port -Port 3000

.EXAMPLE
    if (Test-Port -Port 3000) { Write-Host "Port 3000 is in use" }
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateRange(1, 65535)]
    [int]$Port,

    [Parameter(Mandatory = $false)]
    [int]$Timeout = 500
)

function Test-PortConnection {
    param(
        [string]$HostName = "127.0.0.1",
        [int]$Port,
        [int]$Timeout
    )

    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $connect = $client.BeginConnect($HostName, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)

        if ($wait) {
            try {
                $client.EndConnect($connect)
                $client.Close()
                return @{
                    InUse = $true
                    Reason = "Connection successful"
                }
            } catch {
                return @{
                    InUse = $false
                    Reason = "Connection failed: $($_.Exception.Message)"
                }
            }
        } else {
            return @{
                InUse = $false
                Reason = "Connection timeout"
            }
        }
    } catch {
        return @{
            InUse = $false
            Reason = "Error: $($_.Exception.Message)"
        }
    } finally {
        if ($null -ne $client) {
            $client.Dispose()
        }
    }
}

function Get-ProcessUsingPort {
    param([int]$Port)

    try {
        # Windows: use netstat to find PID
        $netstatOutput = netstat -ano | Select-String ":$Port\s" | Select-String "LISTENING"

        if ($netstatOutput) {
            # Parse the output to get PID
            $parts = $netstatOutput -split '\s+'
            $pid = $parts[-1]

            # Get process details
            $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($process) {
                return @{
                    Pid = $pid
                    Name = $process.ProcessName
                    Path = $process.Path
                }
            }

            return @{
                Pid = $pid
                Name = "Unknown"
                Path = $null
            }
        }

        return $null
    } catch {
        return $null
    }
}

# Main logic
$result = Test-PortConnection -Port $Port -Timeout $Timeout

if ($result.InUse) {
    $processInfo = Get-ProcessUsingPort -Port $Port

    if ($processInfo) {
        Write-Host "Port $Port is in use by PID $($processInfo.Pid) ($($processInfo.Name))"
        if ($processInfo.Path) {
            Write-Host "  Path: $($processInfo.Path)"
        }
    } else {
        Write-Host "Port $Port is in use"
    }

    return $true
} else {
    Write-Host "Port $Port is available ($($result.Reason))"
    return $false
}
