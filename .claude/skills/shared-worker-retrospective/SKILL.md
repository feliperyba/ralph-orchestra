---
name: worker-retrospective
description: Retrospective contribution format for Developer, Tech Artist, QA, and Game Designer worker agents
category: orchestration
version: 2.0
changelog: "P1 FIX: Changed from single shared file to separate contribution files per agent to prevent race conditions."
---

# Worker Retrospective Contributions

**WHEN PM INITIATES A RETROSPECTIVE, YOU MUST CONTRIBUTE YOUR PERSPECTIVE.**

---

## Detecting Retrospective

**POLL for retrospective.txt**:

- When `prd.json.agents.{agent}.status == "awaiting_retrospective"` in prd.json
- Check if `.claude/session/retrospective.txt` exists

---

## What to Do When Retrospective is Triggered

**P1 FIX: Race condition prevention - Use separate contribution files**

1. **READ ALL your task memory files** (MANDATORY FIRST STEP)
   - Directory: `.claude/session/agents/{agent}/`
   - Pattern: `task-*.md` (e.g., task-P1-004-memory.md, task-P1-005-memory.md)
   - Read all sections from all files (Good Points, Pain Points, Technical Decisions, Notes)
   - These files contain everything you noted during task execution
   - Multiple files = you worked on multiple tasks

2. **READ** `.claude/session/retrospective.txt` to get task context

3. **CREATE YOUR OWN CONTRIBUTION FILE** (P1 FIX - Separate file per agent):
   - Developer: `.claude/session/retrospective-developer.json`
   - Tech Artist: `.claude/session/retrospective-techartist.json`
   - QA: `.claude/session/retrospective-qa.json`
   - Game Designer: `.claude/session/retrospective-gamedesigner.json`

4. **WRITE your contribution to your file** (JSON format):
   ```json
   {
     "taskId": "feat-001",
     "agent": "developer",
     "timestamp": "2024-01-20T12:00:00.000Z",
     "contribution": {
       "implementationDecisions": [
         "Used React Three Fiber for scene composition",
         "Chose Rapier for physics simulation"
       ],
       "technicalChallenges": [
         "Synchronizing physics with rendering loop",
         "Managing object pooling for performance"
       ],
       "whatWorkedWell": [
         "Component-based architecture made testing easier",
         "TypeScript caught potential runtime errors"
       ],
       "areasForImprovement": [
         "Need better error handling in physics sync",
         "Object pooling could be more generic"
       ],
       "lessonsLearned": [
         "Prefer R3F abstractions over raw Three.js",
         "Always validate physics state before using"
       ]
     }
   }
   ```

5. **DELETE ALL your task memory files** (MANDATORY CLEANUP)
   - Delete: `.claude/session/agents/{agent}/task-*.md`
   - Verify files are removed

6. **UPDATE** your status in prd.json.agents.{agent}.status to "idle"

7. **LOG** in your progress file

8. **EXIT** - PM will merge all contribution files

**⚠️ CRITICAL: Your retrospective contribution will be GENERIC and USELESS without reading task memory first!**

---

## Why Separate Files? (P1 Fix)

**Previous Problem:** All workers writing to single `retrospective.txt` caused race conditions
- Two workers write simultaneously → last write wins
- File watcher triggers multiple times → inconsistent state
- No atomic write guarantees

**Solution:** Each agent writes to their own file
- No contention between agents
- PM reads all files and merges atomically
- Clear ownership of each contribution

---

## Developer Perspective Format

```markdown
### Developer Perspective

**Implementation Decisions**:

- {{Describe key technical decisions you made}}
- {{Why you chose specific approaches}}

**Technical Challenges Faced**:

- {{What was difficult about this task}}
- {{How you overcame those challenges}}

**What Worked Well**:

- {{Solutions or patterns that worked effectively}}

**Areas for Improvement**:

- {{What could be done better next time}}
- {{Any technical debt or shortcuts taken}}

**Lessons Learned**:

- {{What would help with similar future tasks}}
- {{Suggestions for PRD clarifications}}

_**Contributed by**: Developer Agent | {{ISO_TIMESTAMP}}_
```

---

## QA Perspective Format

```markdown
### QA Perspective

**Validation Results Summary**:

- TypeScript: {{pass/fail}}
- Lint: {{pass/fail}}
- Tests: {{pass/fail}}
- Build: {{pass/fail}}
- Manual/Browser: {{pass/fail}}

**Code Quality Observations**:

- {{Is the code maintainable?}}
- {{Any code smells or anti-patterns?}}
- {{Is there proper error handling?}}
- {{Is the code well-structured?}}

**Quality Concerns**:

- {{Should this be refactored before continuing?}}
- {{Any performance concerns?}}
- {{Is test coverage adequate?}}
- {{Does this follow project patterns?}}

**Suggestions for Improvement**:

- {{What would make this code better?}}
- {{Any areas that need refactoring?}}
- {{Missing tests or coverage?}}

_**Contributed by**: QA Agent | {{ISO_TIMESTAMP}}_
```

---

## Tech Artist Perspective Format

```markdown
### Tech Artist Perspective

**Visual Assets Created**:

- {{Assets/materials/shaders created}}
- {{3D models, textures, effects implemented}}

**Visual Quality Assessment**:

- {{How well visuals match GDD specifications}}
- {{Artistic direction alignment}}
- {{Overall visual polish achieved}}

**Performance Metrics**:

- {{Frame rate impact}}
- {{Draw calls, triangle count}}
- {{Texture memory usage}}
- {{Shader complexity}}

**Challenges Faced**:

- {{What was difficult about visual implementation}}
- {{Shader compilation or optimization issues}}
- {{Asset integration challenges}}

**What Worked Well**:

- {{Visual techniques that were effective}}
- {{Performance optimizations that succeeded}}
- {{Artistic solutions that pleased the Game Designer}}

**Areas for Improvement**:

- {{What could be improved visually}}
- {{Performance bottlenecks to address}}
- {{Asset workflow refinements needed}}

**Lessons Learned**:

- {{What would help with similar visual tasks}}
- {{Shader patterns to reuse}}
- {{Asset pipeline improvements}}

_**Contributed by**: Tech Artist Agent | {{ISO_TIMESTAMP}}_
```

---

## Contribution Guidelines

### Be Specific

- Mention specific files, functions, or patterns you used
- Note any unexpected issues you encountered
- Share what surprised you about the work

### Be Honest

- If you took shortcuts, mention them
- If something felt hacky, say so
- If the PRD was unclear, explain what was confusing

### Be Constructive

- Suggest improvements for future tasks
- Note what would have made this task easier
- Identify areas that might need refactoring later

---

## DO NOT

- ❌ Skip contributing to retrospective
- ❌ Write generic/vague contributions
- ❌ Edit the other agent's sections
- ❌ Delete or modify the retrospective structure
- ❌ Forget to read task memory before contributing
- ❌ Forget to delete ALL task memory files after contributing
- ❌ Create task memory in wrong location (must be task-{taskId}-memory.md format)

---

## Reference

- [ralph-core.md](ralph-core.md) — Session structure and state management
- [ralph-event-protocol.md](ralph-event-protocol.md) — Event-driven messaging protocol
