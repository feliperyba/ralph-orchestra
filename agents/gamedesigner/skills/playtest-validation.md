---
name: playtest-validation
description: Playwright-based game playtesting and design validation
category: gamedesign
depends-on: []
---

# Playtest Validation

## Overview

This skill provides guidance for using Playwright MCP to playtest games and validate implementation against the GDD.

## When to Use This Skill

Use when:
- PM sends `playtest_request` message
- Participating in retrospective
- Validating implementation vs design
- Testing new features

## Playtest Process

### Step 1: Setup

```powershell
# Start the dev server
npm run dev

# Wait for server ready
Start-Sleep -Seconds 5
```

### Step 2: Launch Game via Playwright

```javascript
// Navigate to game
await page.goto('http://localhost:3000');

// Wait for game to load
await page.waitForLoadState('networkidle');

// Capture initial state
await page.screenshot({ path: 'screenshots/playtest-start.png' });
```

### Step 3: Test Core Mechanics

For each mechanic in GDD:

```javascript
// Test movement
await page.keyboard.press('KeyW');
await page.waitForTimeout(1000);
await page.keyboard.up('KeyW');

// Test interaction
await page.click('[data-testid="interact-button"]');

// Test combat
await page.click('[data-testid="attack-button"]');

// Capture state
await page.screenshot({ path: 'screenshots/mechanic-tested.png' });
```

### Step 4: Validate vs GDD

For each GDD requirement:
- [ ] Implemented? (yes/no/partial)
- [ ] Matches design? (yes/no/deviates)
- [ ] Fun factor? (scale 1-5)
- [ ] Issues found?

### Step 5: Document Findings

Create playtest report:

```json
{
  "taskId": "feat-001",
  "playtestedAt": "2025-01-21T12:00:00Z",
  "gddCompliance": {
    "mechanic-name": {
      "status": "matches|deviates|missing",
      "notes": "Description"
    }
  },
  "deviations": [
    {
      "feature": "Mechanic name",
      "expected": "GDD description",
      "actual": "What happens in game",
      "severity": "low|medium|high",
      "screenshot": "path/to/evidence"
    }
  ],
  "issues": [
    {
      "type": "bug|missing|polish",
      "description": "Issue description",
      "severity": "low|medium|high|critical",
      "steps": "How to reproduce"
    }
  ],
  "screenshots": [
    "path/to/screenshot1.png",
    "path/to/screenshot2.png"
  ],
  "overall": {
    "status": "pass|fail|partial",
    "funFactor": 4,
    "notes": "Overall assessment"
  }
}
```

## Playwright MCP Usage

### Starting the Game

```javascript
// Navigate and wait for load
await page.goto('http://localhost:3000');
await page.waitForLoadState('networkidle');
```

### Testing Controls

```javascript
// Keyboard input
await page.keyboard.press('KeyW');
await page.keyboard.up('KeyW');

// Mouse input
await page.mouse.click(x, y);
await page.mouse.down();
await page.mouse.up();

// Touch simulation
await page.touchscreen.tap(x, y);
```

### Monitoring State

```javascript
// Get console messages
page.on('console', msg => {
  console.log(msg.text());
});

// Get page content
const content = await page.content();
```

### Capturing Evidence

```javascript
// Screenshot
await page.screenshot({
  path: 'screenshots/evidence.png',
  fullPage: true
});

// PDF
await page.pdf({
  path: 'report.pdf'
});

// Video (if supported)
// Start recording before gameplay
```

## Validation Categories

### Functional Validation

Does the feature work as intended?
- [ ] Mechanic functions correctly
- [ ] Inputs register properly
- [ ] Outputs are correct
- [ ] Edge cases handled

### Design Validation

Does it match the GDD?
- [ ] Mechanics match description
- [ ] Visuals match art style
- [ ] Audio matches sound design
- [ ] UX matches specifications

### Experience Validation

Is it fun?
- [ ] Game feels good
- [ ] Feedback is satisfying
- [ ] Challenge is appropriate
- [ ] Flow is engaging

## Common Issues to Check

| Issue | Check Method |
|-------|--------------|
| Console errors | Check browser console |
| Visual glitches | Compare to reference |
| Input lag | Test responsiveness |
| Performance | Monitor FPS |
| Crashes | Try stress scenarios |

## Playtest Report Template

```markdown
# Playtest Report - [Task Name]
**Date:** YYYY-MM-DD
**Tester:** Game Designer Agent
**GDD Version:** X.X.X

## Summary
[Overall assessment]

## GDD Compliance

| Mechanic | Status | Notes |
|----------|--------|-------|
| [Name] | ✅/❌/⚠️ | [Details] |

## Deviations Found

| Feature | Expected | Actual | Severity |
|---------|----------|-------|----------|
| [Name] | [GDD] | [Actual] | [High/Med/Low] |

## Issues Found

| ID | Type | Description | Severity | Status |
|----|------|-------------|----------|--------|
| 1 | [Type] | [Description] | [Level] | [Open] |

## Recommendations

1. [Improvement 1]
2. [Improvement 2]
3. [Improvement 3]

## Screenshots
![Screenshot 1](path/to/ss1.png)
![Screenshot 2](path/to/ss2.png)
```

## Sending Playtest Report

After completing playtest:

```powershell
Send-AgentMessage -From "gamedesigner" -To "pm" -Type "playtest_report" -Payload $report
```

## Retrospective Participation

When retrospective initiated:

1. **Play the game** - Full playthrough if possible
2. **Test each mechanic** - Systematic validation
3. **Capture evidence** - Screenshots of key moments
4. **Compare vs GDD** - Note all deviations
5. **Document findings** - Comprehensive report
6. **Send report** - To PM via message
7. **Write to retrospective.txt** - Team contribution

## Playtest Checklist

Before completing playtest:

- [ ] All core mechanics tested
- [ ] Edge cases explored
- [ ] Screenshots captured
- [ ] Console checked for errors
- [ ] Performance monitored
- [ ] GDD compliance validated
- [ ] Findings documented
- [ ] Report sent to PM
