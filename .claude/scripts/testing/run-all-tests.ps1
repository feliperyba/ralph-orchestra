$ErrorActionPreference = "Stop"
# Get project root (2 levels up from testing/ folder)
$ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
Set-Location $ProjectRoot

# Debug: Write paths for troubleshooting
#Write-Host "ProjectRoot: $ProjectRoot"
#Write-Host "PSScriptRoot: $PSScriptRoot"
#Write-Host "Current dir: $(Get-Location)"
#Write-Host "Test path exists: $(Test-Path '.\.claude\scripts\testing\v2-tests\test-v2-eventlog.ps1')"

Write-Host "=== Running All Ralph Tests ===" -ForegroundColor Cyan
Write-Host ""

$results = @()

# Helper to run a test and track result
function Invoke-TestSuite {
    param(
        [string]$Name,
        [string]$ScriptPath
    )

    if (Test-Path $ScriptPath) {
        Write-Host "$Name. Running..." -ForegroundColor Yellow
        & $ScriptPath
        $result = $LASTEXITCODE
        Write-Host "$Name : " -NoNewline
        Write-Host $(if ($result -eq 0) { "PASS" } else { "FAIL" }) -ForegroundColor $(if ($result -eq 0) { "Green" } else { "Red" })
        Write-Host ""
        return @{ Name = $Name; Result = $result; Exists = $true }
    } else {
        Write-Host "$Name : SKIP (file not found)" -ForegroundColor DarkGray
        Write-Host ""
        return @{ Name = $Name; Result = $null; Exists = $false }
    }
}

# ============================================================================
# V2 ARCHITECTURE TESTS
# ============================================================================

Write-Host "--- V2 Architecture Tests ---" -ForegroundColor Cyan
Write-Host ""

$results += Invoke-TestSuite -Name "V2: Event Log" -ScriptPath ".\.claude\scripts\testing\v2-tests\test-v2-eventlog.ps1"
$results += Invoke-TestSuite -Name "V2: Message Protocol" -ScriptPath ".\.claude\scripts\testing\v2-tests\test-v2-messageprotocol.ps1"
$results += Invoke-TestSuite -Name "V2: Event Bus" -ScriptPath ".\.claude\scripts\testing\v2-tests\test-v2-eventbus.ps1"
$results += Invoke-TestSuite -Name "V2: Supervisor" -ScriptPath ".\.claude\scripts\testing\v2-tests\test-v2-supervisor.ps1"
$results += Invoke-TestSuite -Name "V2: Integration" -ScriptPath ".\.claude\scripts\testing\v2-tests\test-v2-integration.ps1"

# ============================================================================
# OPTIONAL TESTS
# ============================================================================

Write-Host "--- Optional Tests (if available) ---" -ForegroundColor Cyan
Write-Host ""

$results += Invoke-TestSuite -Name "Dashboard Cache" -ScriptPath ".\.claude\scripts\testing\test-dashboard-cache.ps1"
$results += Invoke-TestSuite -Name "Handoff Detection" -ScriptPath ".\.claude\scripts\testing\test-handoff-detection.ps1"

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host ""

$totalTests = $results.Count
$passedTests = ($results | Where-Object { $_.Result -eq 0 }).Count
$failedTests = ($results | Where-Object { $_.Result -ne 0 -and $_.Result -ne $null }).Count
$skippedTests = ($results | Where-Object { -not $_.Exists }).Count

Write-Host "Total test suites: $totalTests"
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { "Red" } else { "DarkGray" })
Write-Host "Skipped: $skippedTests" -ForegroundColor DarkGray
Write-Host ""

# Show details of failed tests
foreach ($result in $results) {
    if ($result.Result -ne 0 -and $result.Result -ne $null) {
        Write-Host "  FAILED: $($result.Name)" -ForegroundColor Red
    }
}

if ($failedTests -eq 0) {
    Write-Host "ALL TESTS PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}
