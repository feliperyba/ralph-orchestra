# Ralph Git Worktree Manager
# Enables developer to work on multiple tasks in parallel using git worktrees
# Source this file in other scripts: . "$PSScriptRoot\worktree-manager.ps1"

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:WorktreeConfig = @{
    BaseDir = $null
    ProjectRoot = $null
    WorktreePrefix = "Ralph Orchestra-"
}

function Initialize-WorktreeManager {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectRoot
    )
    
    $Script:WorktreeConfig.ProjectRoot = $ProjectRoot
    $Script:WorktreeConfig.BaseDir = (Get-Item $ProjectRoot).Parent.FullName
    
    Write-Host "[WORKTREE] Initialized for: $ProjectRoot" -ForegroundColor Cyan
}

# ============================================================================
# WORKTREE FUNCTIONS
# ============================================================================

function Get-ActiveWorktrees {
    <#
    .SYNOPSIS
    List all active git worktrees for this project
    #>
    param()
    
    if (-not $Script:WorktreeConfig.ProjectRoot) {
        throw "Worktree manager not initialized."
    }
    
    $worktrees = @()
    
    try {
        Push-Location $Script:WorktreeConfig.ProjectRoot
        
        $output = git worktree list --porcelain 2>&1
        
        $currentWorktree = @{}
        
        foreach ($line in $output) {
            if ($line -match "^worktree (.+)$") {
                if ($currentWorktree.Count -gt 0) {
                    $worktrees += [PSCustomObject]$currentWorktree
                }
                $currentWorktree = @{
                    Path = $Matches[1]
                    Branch = $null
                    Commit = $null
                    IsMain = $false
                }
            } elseif ($line -match "^HEAD (.+)$") {
                $currentWorktree.Commit = $Matches[1]
            } elseif ($line -match "^branch refs/heads/(.+)$") {
                $currentWorktree.Branch = $Matches[1]
            } elseif ($line -match "^bare$") {
                $currentWorktree.IsMain = $true
            }
        }
        
        if ($currentWorktree.Count -gt 0) {
            $worktrees += [PSCustomObject]$currentWorktree
        }
        
        Pop-Location
    } catch {
        Pop-Location
        Write-Host "[WORKTREE] Error listing worktrees: $_" -ForegroundColor Red
    }
    
    return $worktrees
}

function New-TaskWorktree {
    <#
    .SYNOPSIS
    Create a new worktree for a task
    
    .PARAMETER TaskId
    Task ID (e.g., feat-001)
    
    .PARAMETER BaseBranch
    Branch to base the new worktree on (default: main)
    
    .RETURNS
    Path to the new worktree
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        
        [string]$BaseBranch = "main"
    )
    
    if (-not $Script:WorktreeConfig.ProjectRoot) {
        throw "Worktree manager not initialized."
    }
    
    # Security: Validate TaskId to prevent path traversal attacks
    if ($TaskId -notmatch '^[a-zA-Z0-9_-]+$') {
        throw "Invalid TaskId '$TaskId': must contain only alphanumeric characters, hyphens, and underscores"
    }
    if ($TaskId.Length -gt 64) {
        throw "Invalid TaskId '$TaskId': must be 64 characters or less"
    }
    
    $worktreeName = "$($Script:WorktreeConfig.WorktreePrefix)$TaskId"
    $worktreePath = Join-Path $Script:WorktreeConfig.BaseDir $worktreeName
    
    # Check if worktree already exists
    if (Test-Path $worktreePath) {
        Write-Host "[WORKTREE] Worktree already exists: $worktreePath" -ForegroundColor Yellow
        return $worktreePath
    }
    
    try {
        Push-Location $Script:WorktreeConfig.ProjectRoot
        
        # Check if branch already exists
        $branchExists = git branch --list $TaskId 2>&1
        
        if ($branchExists) {
            # Checkout existing branch
            git worktree add $worktreePath $TaskId 2>&1 | Out-Null
        } else {
            # Create new branch from base
            git worktree add -b $TaskId $worktreePath $BaseBranch 2>&1 | Out-Null
        }
        
        Pop-Location
        
        if (Test-Path $worktreePath) {
            Write-Host "[WORKTREE] Created: $worktreePath (branch: $TaskId)" -ForegroundColor Green
            return $worktreePath
        } else {
            throw "Worktree creation failed"
        }
    } catch {
        Pop-Location
        Write-Host "[WORKTREE] Error creating worktree: $_" -ForegroundColor Red
        return $null
    }
}

function Remove-TaskWorktree {
    <#
    .SYNOPSIS
    Remove a worktree after task is complete
    
    .PARAMETER TaskId
    Task ID (e.g., feat-001)
    
    .PARAMETER MergeToMain
    Whether to merge the branch to main before removing
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        
        [switch]$MergeToMain = $false
    )
    
    if (-not $Script:WorktreeConfig.ProjectRoot) {
        throw "Worktree manager not initialized."
    }
    
    $worktreeName = "$($Script:WorktreeConfig.WorktreePrefix)$TaskId"
    $worktreePath = Join-Path $Script:WorktreeConfig.BaseDir $worktreeName
    
    if (-not (Test-Path $worktreePath)) {
        Write-Host "[WORKTREE] Worktree not found: $worktreePath" -ForegroundColor Yellow
        return $true
    }
    
    try {
        Push-Location $Script:WorktreeConfig.ProjectRoot
        
        if ($MergeToMain) {
            Write-Host "[WORKTREE] Merging $TaskId to main..." -ForegroundColor Cyan
            git checkout main 2>&1 | Out-Null
            git merge $TaskId 2>&1 | Out-Null
        }
        
        Write-Host "[WORKTREE] Removing worktree: $worktreePath" -ForegroundColor Yellow
        git worktree remove $worktreePath --force 2>&1 | Out-Null
        
        Pop-Location
        
        Write-Host "[WORKTREE] Removed successfully" -ForegroundColor Green
        return $true
    } catch {
        Pop-Location
        Write-Host "[WORKTREE] Error removing worktree: $_" -ForegroundColor Red
        return $false
    }
}

function Get-WorktreeForTask {
    <#
    .SYNOPSIS
    Get the worktree path for a specific task
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId
    )
    
    $worktreeName = "$($Script:WorktreeConfig.WorktreePrefix)$TaskId"
    $worktreePath = Join-Path $Script:WorktreeConfig.BaseDir $worktreeName
    
    if (Test-Path $worktreePath) {
        return $worktreePath
    }
    
    return $null
}

function Invoke-InWorktree {
    <#
    .SYNOPSIS
    Execute a script block in a worktree directory
    
    .PARAMETER TaskId
    Task ID to get worktree for
    
    .PARAMETER ScriptBlock
    Code to execute in the worktree
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskId,
        
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock
    )
    
    $worktreePath = Get-WorktreeForTask -TaskId $TaskId
    
    if (-not $worktreePath) {
        Write-Host "[WORKTREE] No worktree found for task: $TaskId" -ForegroundColor Yellow
        return $null
    }
    
    try {
        Push-Location $worktreePath
        $result = & $ScriptBlock
        Pop-Location
        return $result
    } catch {
        Pop-Location
        throw $_
    }
}

function Get-WorktreeStatus {
    <#
    .SYNOPSIS
    Get status of all worktrees including git status
    #>
    param()
    
    $worktrees = Get-ActiveWorktrees
    $statuses = @()
    
    foreach ($wt in $worktrees) {
        $status = @{
            Path = $wt.Path
            Branch = $wt.Branch
            IsMain = $wt.Path -eq $Script:WorktreeConfig.ProjectRoot
            HasChanges = $false
            AheadBy = 0
            BehindBy = 0
        }
        
        if (Test-Path $wt.Path) {
            try {
                Push-Location $wt.Path
                
                # Check for uncommitted changes
                $gitStatus = git status --porcelain 2>&1
                $status.HasChanges = $gitStatus.Count -gt 0
                
                # Check ahead/behind
                $tracking = git rev-list --left-right --count HEAD...origin/main 2>&1
                if ($tracking -match "(\d+)\s+(\d+)") {
                    $status.AheadBy = [int]$Matches[1]
                    $status.BehindBy = [int]$Matches[2]
                }
                
                Pop-Location
            } catch {
                Pop-Location
            }
        }
        
        $statuses += [PSCustomObject]$status
    }
    
    return $statuses
}

function Show-WorktreeDashboard {
    <#
    .SYNOPSIS
    Display a dashboard of all worktrees
    #>
    param()
    
    $statuses = Get-WorktreeStatus
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  GIT WORKTREES" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($s in $statuses) {
        $icon = if ($s.IsMain) { "[MAIN]" } else { "[WORK]" }
        $changesIcon = if ($s.HasChanges) { "*" } else { " " }
        $branch = if ($s.Branch) { $s.Branch } else { "(detached)" }
        
        $color = if ($s.IsMain) { "Yellow" } else { "Cyan" }
        
        Write-Host "  $icon " -NoNewline -ForegroundColor $color
        Write-Host "$branch" -NoNewline -ForegroundColor White
        Write-Host " $changesIcon" -NoNewline -ForegroundColor Red
        
        if ($s.AheadBy -gt 0 -or $s.BehindBy -gt 0) {
            Write-Host " (ahead: $($s.AheadBy), behind: $($s.BehindBy))" -NoNewline -ForegroundColor DarkGray
        }
        
        Write-Host ""
        Write-Host "       $($s.Path)" -ForegroundColor DarkGray
        Write-Host ""
    }
    
    Write-Host "========================================" -ForegroundColor Cyan
}

# ============================================================================
# EXPORT
# ============================================================================

# Usage: . "$PSScriptRoot\worktree-manager.ps1"
