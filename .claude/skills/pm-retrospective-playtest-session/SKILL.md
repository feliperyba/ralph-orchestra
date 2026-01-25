---
name: pm-playtest-session
description: Request and process playtest session from Game Designer after retrospective synthesis
---

# Playtest Session Skill

> "Separate playtest phase enables context reset and focused Game Designer validation."

## When to Use This Skill

Use when:

- `currentTask.status === "retrospective_synthesized"`
- Worker retrospective is complete and committed
- Ready to validate implementation through Game Designer playtest
- Before PRD refinement phase

## Quick Start

```powershell
# Phase 1: Request Playtest
if ($currentTask.status -eq "retrospective_synthesized") {
    # Send playtest_session_request to Game Designer
    Send-AgentMessage -From "pm" -To "gamedesigner" -Type "playtest_session_request" -Payload @{
        taskId = $currentTask.id
        taskTitle = $currentTask.title
        retrospectiveComplete = $true
        context = "Retrospective synthesis complete, validate implementation through playtest"
        focus = "all"
        gddReference = "docs/design/gdd.md"
    } -Priority "high"

    # Set status and exit for context reset
    $currentTask.status = "playtest_phase"
    Update-CurrentTask -Task $currentTask
    exit 0
}

# Phase 2: Process Playtest Report (on wake-up)
$playtestReport = Get-PendingMessages | Where-Object { $_.type -eq "playtest_session_report" }
if ($playtestReport) {
    # Review findings
    Review-PlaytestFindings -Report $playtestReport

    # Update PRD if needed based on findings
    if ($playtestReport.payload.issues.Count -gt 0) {
        Update-PRD-Issues -Issues $playtestReport.payload.issues
        # Commit PRD changes
        Invoke-GitCommit -Message "[ralph] [pm] $($currentTask.id): Updated PRD based on playtest findings"
    }

    # Set status and exit for context reset
    $currentTask.status = "playtest_complete"
    Update-CurrentTask -Task $currentTask
    exit 0
}
```

## State Flow

```
retrospective_synthesized → playtest_phase → playtest_complete
```

## Decision Framework

| Status                           | Action                                                      |
| -------------------------------- | ----------------------------------------------------------- |
| `retrospective_synthesized`      | Send `playtest_session_request`, set `playtest_phase`, exit |
| `playtest_phase`                 | Wait for `playtest_session_report`                         |
| `playtest_session_report` received | Review findings, update PRD if needed, commit, set `playtest_complete`, exit |
| `playtest_complete`              | Proceed to PRD refinement phase                             |

## Progressive Guide

### Level 1: Send Playtest Request

After worker retrospective synthesis is complete:

```powershell
# Source message queue
. .\.claude\scripts\message-queue.ps1

# Send playtest_session_request to Game Designer
Send-AgentMessage -From "pm" -To "gamedesigner" -Type "playtest_session_request" -Payload @{
    taskId = $currentTask.id
    taskTitle = $currentTask.title
    retrospectiveComplete = $true
    context = "Retrospective synthesis complete, validate implementation through playtest"
    focus = "all"
    gddReference = "docs/design/gdd.md"
} -Priority "high"

# Update currentTask status
$currentTask.status = "playtest_phase"
Update-CurrentTask -Task $currentTask

# Exit for context reset
exit 0
```

### Level 2: Process Playtest Report

When Game Designer sends `playtest_session_report`:

```powershell
# Check for playtest_session_report message
$messages = Get-PendingMessages -Agent "pm"
$playtestReport = $messages | Where-Object { $_.type -eq "playtest_session_report" }

if ($playtestReport) {
    # Extract findings
    $taskId = $playtestReport.payload.taskId
    $screenshots = $playtestReport.payload.screenshots
    $playwrightUsed = $playtestReport.payload.playwrightUsed
    $visionMcpUsed = $playtestReport.payload.visionMcpUsed
    $findings = $playtestReport.payload.findings
    $gddCompliance = $playtestReport.payload.gddCompliance
    $issues = $playtestReport.payload.issues
    $recommendations = $playtestReport.payload.recommendations

    # Verify mandatory fields
    if (-not $playwrightUsed -or -not $visionMcpUsed) {
        Send-AgentMessage -From "pm" -To "gamedesigner" -Type "question" -Payload @{
            question = "Playtest must use Playwright MCP and Vision MCP. Please re-run playtest."
        } -Priority "high"
        exit 0
    }

    # Review findings
    Write-Host "Playtest findings for $taskId :" -ForegroundColor Cyan
    Write-Host "  GDD Compliance: $gddCompliance" -ForegroundColor (if ($gddCompliance -eq "pass") { "Green" } else { "Yellow" })
    Write-Host "  Findings: $findings"

    if ($issues.Count -gt 0) {
        Write-Host "  Issues found:" -ForegroundColor Yellow
        foreach ($issue in $issues) {
            Write-Host "    - $issue" -ForegroundColor Yellow
        }

        # Create tasks for issues if needed
        foreach ($issue in $issues) {
            # Check if issue already has a task
            $existingTask = Find-TaskByIssue -Issue $issue
            if (-not $existingTask) {
                New-PRDTask -Issue $issue -Source "playtest"
            }
        }
    }

    # Update PRD if needed
    if ($issues.Count -gt 0 -or $recommendations.Count -gt 0) {
        Update-PRD-From-Playtest -Issues $issues -Recommendations $recommendations

        # Commit PRD changes
        $commitMessage = "[ralph] [pm] $($taskId): Updated PRD based on playtest findings"
        Invoke-GitCommit -Message $commitMessage
    }

    # Acknowledge message
    Invoke-AcknowledgeMessage -MessageId $playtestReport.id -Agent "pm"

    # Set status to playtest_complete
    $currentTask.status = "playtest_complete"
    Update-CurrentTask -Task $currentTask

    # Exit for context reset
    exit 0
}
```

## Message Types

### playtest_session_request (PM → Game Designer)

```json
{
  "id": "msg-playtest-session-{timestamp}",
  "from": "pm",
  "to": "gamedesigner",
  "type": "playtest_session_request",
  "priority": "high",
  "payload": {
    "taskId": "feat-001",
    "taskTitle": "Completed task title",
    "retrospectiveComplete": true,
    "context": "Retrospective synthesis complete, validate implementation through playtest",
    "focus": "all",
    "gddReference": "docs/design/gdd.md"
  },
  "timestamp": "{ISO-8601-UTC}",
  "status": "pending"
}
```

### playtest_session_report (Game Designer → PM)

```json
{
  "id": "msg-playtest-report-{timestamp}",
  "from": "gamedesigner",
  "to": "pm",
  "type": "playtest_session_report",
  "priority": "high",
  "payload": {
    "taskId": "feat-001",
    "screenshots": ["playtest-feat-001-start.png", "playtest-feat-001-during.png", "playtest-feat-001-end.png"],
    "playwrightUsed": true,
    "visionMcpUsed": true,
    "findings": "Gameplay mechanics working as expected, visual polish needs improvement",
    "gddCompliance": "pass",
    "issues": [],
    "recommendations": []
  },
  "timestamp": "{ISO-8601-UTC}",
  "status": "pending"
}
```

## Anti-Patterns

❌ **DON'T:**

- Skip playtest session and go directly to PRD refinement
- Accept playtest without verifying Playwright MCP was used
- Accept playtest without verifying Vision MCP was used
- Forget to commit PRD changes if issues were found
- Skip updating PRD with playtest findings

✅ **DO:**

- Always request playtest after retrospective synthesis
- Verify `playwrightUsed: true` in playtest report
- Verify `visionMcpUsed: true` in playtest report
- Commit PRD changes if issues were found
- Update PRD with playtest findings and recommendations
- Exit after each step for context reset

## Checklist

**Before sending playtest request:**
- [ ] Worker retrospective is complete
- [ ] Retrospective synthesis is committed
- [ ] Current task status is `retrospective_synthesized`

**After receiving playtest report:**
- [ ] Playwright MCP was used (`playwrightUsed: true`)
- [ ] Vision MCP was used (`visionMcpUsed: true`)
- [ ] At least 3 screenshots included
- [ ] GDD compliance status is documented
- [ ] PRD updated if issues found
- [ ] PRD changes committed (if applicable)
- [ ] Status set to `playtest_complete`
- [ ] Exited for context reset

## Post-Playtest

After playtest is complete:

1. Set `currentTask.status = "playtest_complete"`
2. Proceed to PRD refinement phase
3. Use `pm-prd-organization` skill to extract/update tasks
4. Send `prd_analysis_request` to Game Designer

## Reference

- [`.claude/skills/pm-retrospective/SKILL.md`](../pm-retrospective/SKILL.md) — Worker retrospective phase
- [`.claude/skills/pm-prd-organization/SKILL.md`](../pm-prd-organization/SKILL.md) — PRD refinement phase
- [`agents/pm/AGENT.md`](../../../agents/pm/AGENT.md) — Full PM instructions
- [`.claude/skills/ralph-event-protocol/SKILL.md`](../ralph-event-protocol/SKILL.md) — Message protocol
