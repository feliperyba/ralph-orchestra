---
name: design-validation
description: Checklist for validating design implementation during playtesting
category: gamedesign
depends-on: [playtest-validation]
---

# Design Validation Checklist

Use this checklist during retrospectives to validate implementation against the GDD.

## Preparation

### Load Documents
- [ ] GDD read and understood
- [ ] Current task ID identified
- [ ] Relevant GDD sections noted

### Setup Environment
- [ ] Dev server started (`npm run dev`)
- [ ] Browser navigated to game
- [ ] Playwright MCP ready
- [ ] Screenshot directory prepared

---

## Mechanics Validation

For each core mechanic in GDD:

### Movement
- [ ] Matches GDD description (speed, controls)
- [ ] Visual feedback matches design
- [ ] Audio feedback matches design
- [ ] Edge cases handled

### Combat
- [ ] Damage values match GDD
- [ ] Hit detection works as specified
- [ ] Weapons behave as designed
- [ ] Death/respawn matches design

### Interaction
- [ ] Object interaction works
- [ ] UI feedback is clear
- [ ] Input registration is reliable
- [ ] Timing matches specification

### Progression
- [ ] XP/rewards match GDD
- [ ] Leveling occurs as designed
- [ ] Unlocks happen correctly
- [ ] Save/load works (if applicable)

### Multiplayer
- [ ] Match structure matches design
- [ ] Team balancing works
- [ ] Network performance acceptable
- [ ] Latency handling functional

---

## Visual Validation

### Art Style
- [ ] Matches visual language guide
- [ ] Assets are consistent
- [ ] Color palette matches design
- [ ] Animation style appropriate

### UI/UX
- [ ] HUD matches GDD specs
- [ ] Menu flow matches design
- [ ] Controls match GDD
- [ ] Accessibility features present

### Environment
- [ ] Map layouts match templates
- [ ] Landmarks are visible
- [ ] Spawn points work as designed
- [ ] Extraction points match design

---

## Audio Validation

### Sound Design
- [ ] Footstep sounds match surface
- [ ] Weapon sounds are distinctive
- [ ] Ambient audio is appropriate
- [ ] Music cues work as designed

### Feedback
- [ ] Action sounds trigger correctly
- [ ] Impact sounds communicate force
- [ ] Alert sounds are attention-grabbing
- [ ] UI sounds provide feedback

---

## Experience Validation

### Fun Factor
- [ ] Core loop is engaging
- [ ] Actions feel responsive
- [ ] Feedback is satisfying
- [ ] Challenge is appropriate

### Learning Curve
- [ ] New player can understand basics
- [ ] Tutorial is effective (if present)
- [ ] Advanced play is rewarded
- [ ] Mistakes are recoverable

### Pacing
- [ ] Session length is appropriate
- [ ] Downtime doesn't bore
- [ ] Peaks aren't overwhelming
- [ ] Climax is satisfying

---

## Compliance Summary

| GDD Section | Status | Deviations | Notes |
|-------------|--------|------------|-------|
| Overview | ✅/❌/⚠️ | | |
| Core Gameplay | ✅/❌/⚠️ | | |
| Mechanics | ✅/❌/⚠️ | | |
| Characters | ✅/❌/⚠️ | | |
| Weapons | ✅/❌/⚠️ | | |
| Levels | ✅/❌/⚠️ | | |
| UI/UX | ✅/❌/⚠️ | | |
| Progression | ✅/❌/⚠️ | | |
| Multiplayer | ✅/❌/⚠️ | | |
| Audio/Visual | ✅/❌/⚠️ | | |

---

## Issues Found

### Critical
[List any critical blockers]

### High
[List important issues]

### Medium
[List moderate issues]

### Low
[List minor issues or polish items]

---

## Recommendations

### Priority 1 (Must Fix)
1. [Issue]
2. [Issue]

### Priority 2 (Should Fix)
1. [Issue]
2. [Issue]

### Priority 3 (Nice to Have)
1. [Issue]
2. [Issue]

---

## Test Evidence

### Screenshots
- [ ] Initial state captured
- [ ] Key mechanics tested
- [ ] Issues documented with screenshots
- [ ] Final state captured

### Console Logs
- [ ] No errors
- [ ] No critical warnings
- [ ] Performance acceptable

---

## Report Generation

After completing validation, send report:

```powershell
Send-AgentMessage -From "gamedesigner" -To "pm" -Type "playtest_report" -Payload @{
    taskId = $taskId
    gddCompliance = $compliance
    deviations = $deviations
    issues = $issues
    screenshots = $screenshotPaths
    recommendations = $recommendations
    validatedAt = (Get-Date).ToUniversalTime().ToString("o")
    overall = @{
        status = "pass|fail|partial"
        funFactor = 1-5
        notes = "Summary"
    }
}
```
