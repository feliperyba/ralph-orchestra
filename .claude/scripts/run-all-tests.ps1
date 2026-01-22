$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $ProjectRoot

Write-Host "=== Running All Tests ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Integration Tests
Write-Host "1. Running Integration Tests..." -ForegroundColor Yellow
& ".\.claude\scripts\test-integration.ps1"
$intResult = $LASTEXITCODE
Write-Host "Integration Tests: " -NoNewline
Write-Host $(if ($intResult -eq 0) { "PASS" } else { "FAIL" }) -ForegroundColor $(if ($intResult -eq 0) { "Green" } else { "Red" })

Write-Host ""

# Test 2: Recovery Tests
Write-Host "2. Running Recovery Tests..." -ForegroundColor Yellow
& ".\.claude\scripts\test-recovery.ps1"
$recResult = $LASTEXITCODE
Write-Host "Recovery Tests: " -NoNewline
Write-Host $(if ($recResult -eq 0) { "PASS" } else { "FAIL" }) -ForegroundColor $(if ($recResult -eq 0) { "Green" } else { "Red" })

Write-Host ""

# Test 3: Concurrency Tests
Write-Host "3. Running Concurrency Tests..." -ForegroundColor Yellow
& ".\.claude\scripts\test-concurrency.ps1"
$conResult = $LASTEXITCODE
Write-Host "Concurrency Tests: " -NoNewline
Write-Host $(if ($conResult -eq 0) { "PASS" } else { "FAIL" }) -ForegroundColor $(if ($conResult -eq 0) { "Green" } else { "Red" })

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
$allPassed = ($intResult -eq 0) -and ($recResult -eq 0) -and ($conResult -eq 0)
Write-Host "Overall: " -NoNewline
Write-Host $(if ($allPassed) { "ALL TESTS PASSED" } else { "SOME TESTS FAILED" }) -ForegroundColor $(if ($allPassed) { "Green" } else { "Red" })

exit $(if ($allPassed) { 0 } else { 1 })
