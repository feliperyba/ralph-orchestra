# Ralph Dashboard Common Module
# Shared display utilities for watchdog dashboard rendering
#
# Usage: . "$PSScriptRoot\Dashboard-Common.ps1"

# Source configuration if not already loaded
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Get-Command "Get-RalphConfig" -ErrorAction SilentlyContinue)) {
    . "$scriptDir\ralph-config.ps1"
}

# ============================================================================
# STATUS COLOR MAPPING
# ============================================================================

function Get-StatusColor {
    <#
    .SYNOPSIS
    Gets the console color for displaying an agent status.

    .PARAMETER Status
    The agent status string (e.g., "idle", "working", "starting", "stopped")

    .RETURNS
    The ConsoleColor to use for display.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Status
    )

    switch ($Status) {
        "stopped" { return "Red" }
        "idle" { return "Gray" }
        "working" { return "Green" }
        "waiting" { return "Yellow" }
        "ready" { return "Cyan" }
        "starting" { return "Magenta" }
        "completed" { return "Green" }
        "terminated" { return "DarkGray" }
        "error" { return "Red" }
        default { return "White" }
    }
}

# ============================================================================
# STRING FORMATTING
# ============================================================================

function Format-UptimeString {
    <#
    .SYNOPSIS
    Formats a TimeSpan as a readable uptime string.

    .PARAMETER Uptime
    The TimeSpan to format.

    .RETURNS
    Formatted uptime string (e.g., "01:23:45").
    #>
    param(
        [Parameter(Mandatory=$true)]
        [TimeSpan]$Uptime
    )

    return "{0:hh\:mm\:ss}" -f $Uptime
}

function Format-DashboardBorder {
    <#
    .SYNOPSIS
    Creates a border string for dashboard display.

    .PARAMETER Width
    The width of the dashboard (default: 80).

    .PARAMETER Character
    The character to use for the border (default: "=").

    .RETURNS
    Border string of specified width.
    #>
    param(
        [int]$Width = 80,
        [string]$Character = "="
    )

    return $Character * $Width
}

function Format-DashboardSeparator {
    <#
    .SYNOPSIS
    Creates a separator string for dashboard sections.

    .PARAMETER Width
    The width of the dashboard (default: 80).

    .RETURNS
    Separator string with padding.
    #>
    param(
        [int]$Width = 80
    )

    return "  " + ("-" * ($Width - 4))
}

# ============================================================================
# DASHBOARD CELL FORMATTING
# ============================================================================

function Format-DashboardCell {
    <#
    .SYNOPSIS
    Formats a cell value for dashboard display with padding.

    .PARAMETER Value
    The value to display.

    .PARAMETER Width
    The target width of the cell.

    .PARAMETER Align
    Alignment: "Left" or "Right" (default: "Left").

    .RETURNS
    Padded string value.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value,

        [int]$Width = 12,

        [ValidateSet("Left", "Right")]
        [string]$Align = "Left"
    )

    if ($Value.Length -ge $Width) {
        return $Value.Substring(0, $Width)
    }

    $padded = $Value.PadRight($Width)
    if ($Align -eq "Right") {
        $padded = $Value.PadLeft($Width)
    }

    return $padded
}

# ============================================================================
# EXPORTED FUNCTIONS (when dot-sourced, all functions are available)
# ============================================================================
# Get-StatusColor
# Format-UptimeString
# Format-DashboardBorder
# Format-DashboardSeparator
# Format-DashboardCell
