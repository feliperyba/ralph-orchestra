# Ralph Dashboard Common Module
# Shared display utilities for watchdog dashboard rendering
#
# Usage: . "$PSScriptRoot\Dashboard-Common.ps1"

# Source configuration if not already loaded
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Get-Command "Get-RalphConfig" -ErrorAction SilentlyContinue)) {
    . "$scriptDir\..\core\ralph-config.ps1"
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
# RALPH STARTUP ANIMATION
# ============================================================================

# Cached ASCII art
$Script:RalphAsciiArt = $null

function Get-RalphCharColor {
    <#
    .SYNOPSIS
    Gets the console color for each character in Ralph ASCII art.
    Based on Ralph Wiggum's appearance - yellow skin, cyan shirt, red accents.

    .PARAMETER Char
    The character to get the color for.

    .RETURNS
    The ConsoleColor to use for the character.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [char]$Char
    )

    switch ($Char) {
        # Yellow/gold - Ralph's skin (main character body)
        '#' { return 'Yellow' }

        # Cyan - shirt and accents
        '+' { return 'Cyan' }

        # DarkYellow/brown - frame and outlines
        '-' { return 'DarkYellow' }

        # DarkGray - shading and details
        '.' { return 'DarkGray' }

        # Default - skin color for any other character
        default { return 'Yellow' }
    }
}

function Write-RalphAsciiLine {
    <#
    .SYNOPSIS
    Writes a single line of Ralph ASCII art with colored characters.

    .PARAMETER Line
    The ASCII art line to render.

    .PARAMETER Indent
    Number of spaces to indent before the line.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Line,

        [int]$Indent = 0
    )

    # Write leading spaces (no color)
    if ($Indent -gt 0) {
        Write-Host (" " * $Indent) -NoNewline
    }

    # Write each character with its color
    foreach ($char in $line.ToCharArray()) {
        $color = Get-RalphCharColor -Char $char
        Write-Host $char -ForegroundColor $color -NoNewline
    }
    Write-Host  # New line after the line
}

function Get-RalphAsciiArt {
    <#
    .SYNOPSIS
    Loads and returns the Ralph Wiggum ASCII art from docs/ralph.txt.

    .RETURNS
    String array containing the ASCII art lines.
    #>
    if ($null -ne $Script:RalphAsciiArt) {
        return $Script:RalphAsciiArt
    }

    # Try to find ralph.txt in docs directory
    $ralphPath = Join-Path $scriptDir "..\..\..\docs\ralph.txt"
    if (-not (Test-Path $ralphPath)) {
        # Fallback to project root docs
        $projectRoot = (Get-Item $scriptDir).Parent.Parent.Parent.FullName
        $ralphPath = Join-Path $projectRoot "docs\ralph.txt"
    }

    if (Test-Path $ralphPath) {
        $Script:RalphAsciiArt = Get-Content -Path $ralphPath -Encoding UTF8
    } else {
        # Fallback art if file not found
        $Script:RalphAsciiArt = @(
            "     ___",
            "    /   \",
            "   | Ralph |",
            "    \___/",
            "   Orchestra"
        )
    }

    return $Script:RalphAsciiArt
}

function Show-RalphStartupAnimation {
    <#
    .SYNOPSIS
    Displays Ralph ASCII art during startup, then clears.
    Ralph appears once at current cursor position.

    .PARAMETER Supervisor
    The ActorSupervisor instance to check agent connection status.

    .PARAMETER MaxDurationSeconds
    Maximum animation duration (default: 3 seconds).

    .RETURNS
    True if animation completed successfully, False if error occurred.
    #>
    param(
        [object]$Supervisor,
        [int]$MaxDurationSeconds = 3
    )

    try {
        $asciiArt = Get-RalphAsciiArt
        $artHeight = $asciiArt.Count
        $artWidth = ($asciiArt | Measure-Object -Property Length -Maximum).Maximum
        $startTime = [DateTime]::UtcNow

        # Get RawUI for cursor positioning
        $rawui = $Host.UI.RawUI
        if ($null -eq $rawui) {
            return $false
        }

        # Get console dimensions
        $consoleHeight = 24
        try {
            if ($null -ne $rawui.WindowSize) {
                $consoleHeight = $rawui.WindowSize.Height
            }
        } catch {
            # Use defaults
        }

        # Starting position - left side, ensure Y is within bounds
        $startX = 2
        $startY = [Math]::Max(0, [Math]::Floor(($consoleHeight - $artHeight) / 2))

        # Save original cursor position
        $originalCursor = $rawui.CursorPosition

        # Draw Ralph once at starting position
        for ($y = 0; $y -lt $artHeight; $y++) {
            $targetY = $startY + $y

            if ($targetY -ge 0 -and $targetY -lt $consoleHeight) {
                # Position cursor
                $rawui.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $startX, $targetY

                # Write colored line
                $line = $asciiArt[$y]
                foreach ($char in $line.ToCharArray()) {
                    $color = Get-RalphCharColor -Char $char
                    Write-Host $char -ForegroundColor $color -NoNewline
                }
            }
        }

        # Brief pause to see Ralph
        Start-Sleep -Milliseconds 500

        # Clear Ralph
        for ($y = 0; $y -lt $artHeight; $y++) {
            if ($startY + $y -lt $consoleHeight) {
                $rawui.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $startX, ($startY + $y)
                Write-Host (" " * $artWidth) -NoNewline
            }
        }

        # Restore original cursor position
        $rawui.CursorPosition = $originalCursor

        return $true

    } catch {
        Write-Warning "Animation error: $_"
        return $false
    }
}

# ============================================================================
# EXPORTED FUNCTIONS (when dot-sourced, all functions are available)
# ============================================================================
# Get-StatusColor
# Format-UptimeString
# Format-DashboardBorder
# Format-DashboardSeparator
# Format-DashboardCell
# Get-RalphCharColor
# Write-RalphAsciiLine
# Get-RalphAsciiArt
# Show-RalphStartupAnimation
