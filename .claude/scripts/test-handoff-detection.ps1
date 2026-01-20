# Test script for handoff detection
# Run: .\.claude\scripts\test-handoff-detection.ps1

param(
    [string]$TestContent = "",
    [switch]$CreateTestSignal = $false
)

$ErrorActionPreference = "Stop"

# Source configuration
$ProjectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
. "$PSScriptRoot\ralph-config.ps1"
$paths = Get-RalphPaths -ProjectRoot $ProjectRoot

$LogDir = Join-Path $paths.SessionDir "logs"
$SessionDir = $paths.SessionDir

# Create test log directory
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Handoff pattern (same as watchdog)
$HandoffPattern = 'HANDOFF\s*:\s*(pm|developer|qa)\s*:\s*(.+)'
$CompletionPattern = '<promise>RALPH_COMPLETE</promise>'
$GracefulExitPattern = 'AGENT_READY_FOR_HANDOFF'

function Test-SignalFile {
    $signalFile = Join-Path $SessionDir "handoff-signal.json"
    
    Write-Host "`n=== Testing Signal File Detection ===" -ForegroundColor Cyan
    
    if (Test-Path $signalFile) {
        Write-Host "✅ Signal file exists: $signalFile" -ForegroundColor Green
        $content = Get-Content $signalFile -Raw
        Write-Host "Content:" -ForegroundColor Yellow
        Write-Host $content -ForegroundColor Gray
        
        try {
            $json = $content | ConvertFrom-Json
            if ($json.type -eq "complete") {
                Write-Host "Type: COMPLETE" -ForegroundColor Green
            } elseif ($json.targetAgent) {
                Write-Host "Target Agent: $($json.targetAgent)" -ForegroundColor Cyan
                Write-Host "Context: $($json.context)" -ForegroundColor Cyan
            }
        } catch {
            Write-Host "❌ Failed to parse JSON: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "No signal file found at: $signalFile" -ForegroundColor Yellow
    }
}

function Test-HandoffDetection {
    param([string]$Content)
    
    Write-Host "`n=== Testing Log Pattern Detection ===" -ForegroundColor Cyan
    Write-Host "Content length: $($Content.Length) chars" -ForegroundColor DarkGray
    Write-Host "`nContent:" -ForegroundColor Yellow
    Write-Host $Content -ForegroundColor Gray
    Write-Host ""
    
    # Test completion
    if ($Content -match $CompletionPattern) {
        Write-Host "✅ MATCH: Completion pattern found" -ForegroundColor Green
        return
    }
    
    # Test handoff
    if ($Content -match $HandoffPattern) {
        Write-Host "✅ MATCH: Handoff pattern found!" -ForegroundColor Green
        Write-Host "  Target Agent: $($Matches[1])" -ForegroundColor Cyan
        Write-Host "  Context: $($Matches[2])" -ForegroundColor Cyan
        return
    }
    
    # Test graceful exit
    if ($Content -match $GracefulExitPattern) {
        Write-Host "⚠️  PARTIAL: AGENT_READY_FOR_HANDOFF found but no HANDOFF: line" -ForegroundColor Yellow
        return
    }
    
    Write-Host "❌ NO MATCH: No handoff pattern found" -ForegroundColor Red
}

# Create test signal if requested
if ($CreateTestSignal) {
    $signalFile = Join-Path $SessionDir "handoff-signal.json"
    $testSignal = @{
        targetAgent = "developer"
        context = "Test handoff - Implement test feature"
        timestamp = [DateTime]::UtcNow.ToString("o")
    }
    $testSignal | ConvertTo-Json | Out-File -FilePath $signalFile -Encoding UTF8
    Write-Host "Created test signal file: $signalFile" -ForegroundColor Green
}

# Test signal file first (primary method)
Test-SignalFile

# Test log patterns
$testCases = @(
    @{
        Name = "Simple handoff"
        Content = "HANDOFF:developer:Implement feature X"
    },
    @{
        Name = "Handoff with spaces"
        Content = "HANDOFF : developer : Implement feature X"
    },
    @{
        Name = "Completion"
        Content = "<promise>RALPH_COMPLETE</promise>"
    }
)

Write-Host "`n=== Log Pattern Test Suite ===" -ForegroundColor Magenta
Write-Host "Pattern: $HandoffPattern" -ForegroundColor DarkGray

foreach ($test in $testCases) {
    Write-Host "`n--- Test: $($test.Name) ---" -ForegroundColor White
    Test-HandoffDetection -Content $test.Content
}

# Test actual log file if exists
$pmLog = Join-Path $LogDir "pm.log"
if (Test-Path $pmLog) {
    Write-Host "`n=== Actual PM Log ===" -ForegroundColor Magenta
    $lines = Get-Content $pmLog -Tail 30 -ErrorAction SilentlyContinue
    $content = $lines -join "`n"
    Test-HandoffDetection -Content $content
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
Write-Host "To create a test signal file, run:" -ForegroundColor DarkGray
Write-Host "  .\.claude\scripts\test-handoff-detection.ps1 -CreateTestSignal" -ForegroundColor White
