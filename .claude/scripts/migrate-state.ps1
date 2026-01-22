# Ralph State Migration Script
# Migrates monolithic coordinator-state.json to split state files (Phase 2)

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectRoot = (Get-Item (Split-Path $PSScriptRoot -Parent).Parent).FullName,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$Backup
)

$ErrorActionPreference = "Stop"

# Source dependencies
. "$PSScriptRoot\split-state-manager.ps1"

$paths = @{
    SessionDir = Join-Path $ProjectRoot ".claude\session"
    OldStateFile = Join-Path $ProjectRoot ".claude\session\coordinator-state.json"
    BackupDir = Join-Path $ProjectRoot ".claude\session\backup"
}

function Write-MigrationLog {
    param(
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    Write-Host "[STATE-MIGRATION] $Message" -ForegroundColor $Color
}

function Backup-ExistingState {
    if (-not (Test-Path $paths.OldStateFile)) {
        return $false
    }

    $backupPath = Join-Path $paths.BackupDir "coordinator-state-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

    if (-not (Test-Path $paths.BackupDir)) {
        New-Item -ItemType Directory -Path $paths.BackupDir -Force | Out-Null
    }

    Copy-Item -Path $paths.OldStateFile -Destination $backupPath -Force
    Write-MigrationLog "Backup created: $backupPath" -Color Green

    return $true
}

function Test-MigrationNeeded {
    # Check if old state file exists
    if (-not (Test-Path $paths.OldStateFile)) {
        Write-MigrationLog "No existing coordinator-state.json found" -Color Yellow
        return $false
    }

    # Check if migration already done
    $stateDir = Join-Path $paths.SessionDir "state"
    $agentsFile = Join-Path $stateDir "agents.json"

    if (Test-Path $agentsFile) {
        Write-MigrationLog "Split state files already exist. Use -Force to re-migrate." -Color Yellow
        return $false
    }

    return $true
}

function Migrate-State {
    <#
    .SYNOPSIS
    Migrate coordinator-state.json to split state files.
    #>
    param()

    Write-MigrationLog "Starting migration..." -Color Cyan

    # Read old state
    Write-MigrationLog "Reading coordinator-state.json..." -Color Gray
    $oldState = Get-Content $paths.OldStateFile -Raw | ConvertFrom-Json

    # Initialize split state manager
    Initialize-SplitStateManager -SessionDir $paths.SessionDir

    # Migrate agent states
    Write-MigrationLog "Migrating agent states..." -Color Gray
    $agentsState = @{
        pm = @{ status = "idle"; ProcessState = "stopped"; pid = $null; LastSeen = $null }
        developer = @{ status = "idle"; ProcessState = "stopped"; pid = $null; LastSeen = $null }
        qa = @{ status = "idle"; ProcessState = "stopped"; pid = $null; LastSeen = $null }
        gamedesigner = @{ status = "idle"; ProcessState = "stopped"; pid = $null; LastSeen = $null }
        techartist = @{ status = "idle"; ProcessState = "stopped"; pid = $null; LastSeen = $null }
    }

    if ($oldState.agents) {
        foreach ($agent in $oldState.agents.PSObject.Properties.Name) {
            if ($agentsState[$agent]) {
                $agentsState[$agent] = $oldState.agents.$agent
            }
        }
    }

    Set-StateFile -Name "agents" -Data $agentsState -AgentName "migration" -UseLock

    # Migrate PRD state
    Write-MigrationLog "Migrating PRD state..." -Color Gray
    $prdState = @{
        version = "2.0"
        tasks = @{}
        currentTask = $null
    }

    if ($oldState.prd) {
        $prdState = $oldState.prd
    }

    Set-StateFile -Name "prd" -Data $prdState -AgentName "migration" -UseLock

    # Migrate current task
    Write-MigrationLog "Migrating current task..." -Color Gray
    $taskState = @{
        taskId = $null
        agent = $null
        status = "idle"
        startTime = $null
    }

    if ($oldState.currentTask) {
        $taskState = $oldState.currentTask
    }

    Set-StateFile -Name "current-task" -Data $taskState -AgentName "migration" -UseLock

    # Initialize metrics
    Write-MigrationLog "Initializing metrics..." -Color Gray
    $metrics = @{
        startTime = [DateTime]::UtcNow.ToString("o")
        totalMessagesRouted = 0
        totalIterations = 0
        uptimeSeconds = 0
    }

    if ($oldState.iteration) {
        $metrics.totalIterations = $oldState.iteration
    }

    Set-StateFile -Name "metrics" -Data $metrics -AgentName "migration" -UseLock

    Write-MigrationLog "Migration complete!" -Color Green

    # Show report
    Show-SplitStateReport
}

function Verify-Migration {
    <#
    .SYNOPSIS
    Verify that migration was successful.
    #>
    param()

    Write-MigrationLog "Verifying migration..." -Color Cyan

    $stateDir = Join-Path $paths.SessionDir "state"
    $allExist = $true

    foreach ($file @("agents.json", "prd.json", "current-task.json", "metrics.json")) {
        $filePath = Join-Path $stateDir $file
        if (Test-Path $filePath) {
            Write-MigrationLog "  ✓ $file" -Color Green
        } else {
            Write-MigrationLog "  ✗ $file MISSING" -Color Red
            $allExist = $false
        }
    }

    return $allExist
}

# ============================================================================
# MAIN
# ============================================================================

Write-MigrationLog "Ralph Orchestra State Migration" -Color Cyan
Write-MigrationLog "=================================" -Color Cyan
Write-MigrationLog "Project Root: $ProjectRoot" -Color Gray
Write-MigrationLog ""

# Check if migration is needed
if (-not (Test-MigrationNeeded)) {
    Write-MigrationLog "No migration needed. Exiting." -Color Green
    exit 0
}

# Dry run mode
if ($DryRun) {
    Write-MigrationLog "DRY RUN MODE - No changes will be made" -Color Yellow
    Write-MigrationLog "Would migrate: $($paths.OldStateFile)" -Color Gray
    exit 0
}

# Backup existing state
if ($Backup) {
    Backup-ExistingState
}

# Perform migration
try {
    Migrate-State

    # Verify
    if (Verify-Migration) {
        Write-MigrationLog "" -Color White
        Write-MigrationLog "Migration verified successfully!" -Color Green

        # Rename old state file
        $archivePath = "$($paths.OldStateFile).legacy"
        Move-Item -Path $paths.OldStateFile -Destination $archivePath -Force
        Write-MigrationLog "Old state archived to: $archivePath" -Color Gray
    } else {
        Write-MigrationLog "Migration verification FAILED!" -Color Red
        exit 1
    }
} catch {
    Write-MigrationLog "Migration FAILED: $_" -Color Red
    exit 1
}
