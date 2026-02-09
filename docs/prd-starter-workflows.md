# PRD Starter Workflows

> Integration patterns for PRD Starter wizard outputs with Ralph Orchestra orchestration modes and development workflows.

## Overview

The PRD Starter Wizard generates a complete project structure, but understanding how these artifacts integrate with orchestration is crucial for effective development. This guide covers:

- How generated agents integrate with orchestration modes
- When and how to use generated PRD and research artifacts
- Managing and updating generated configurations
- Common workflow patterns for different project types

## Agent Integration

### Generated Agent Files

The wizard creates agent definitions that seamlessly integrate with Ralph Orchestra:

**File structure:**
```
agents/{name}/
├── AGENT.md          # Agent behavior and responsibilities
└── SKILLS.md         # Skills index (references to .claude/skills/)
```

**.claude/settings.{name}.json** - MCP server configuration per agent

### Event-Driven Mode Integration

**Watchdog monitors:** `agents/{name}/` directories for `.request` files

**Workflow:**
1. Coordinator creates task: `agents/developer/task-001.request`
2. Watchdog detects file, invokes developer agent via Claude CLI
3. Developer agent uses AGENT.md for context
4. Agent writes result: `agents/developer/task-001.result`
5. Watchdog delivers result to coordinator via messages

**Generated script updates:**
- `watchdog-event.ps1` knows about your custom agents
- `message-queue.ps1` routes messages to correct agents
- `ralph-event-session.ps1` launches agents with proper settings

**Command pattern:**
```powershell
# Start event-driven orchestration
/ralph-coordinator-event

# Watchdog automatically manages worker agents
```

### Sequential Mode Integration

**Handoff pattern:** Coordinator → Agent 1 → Agent 2 → ... → Coordinator

**Workflow:**
1. Coordinator assigns task with handoff instructions
2. Agent 1 completes work, writes handoff directive
3. Watchdog (or coordinator) invokes Agent 2
4. Process continues until final agent hands back to coordinator

**Generated script updates:**
- `watchdog-single.ps1` recognizes handoff keywords for your agents
- `ralph-single-session.ps1` validates agent names

**Command pattern:**
```bash
# Start sequential orchestration
/ralph-coordinator-single
```

### HITL Mode Integration

**Learning mode:** Human reviews and approves each agent action

**Workflow:**
1. Agent proposes action
2. Human reviews proposal
3. Human approves, rejects, or modifies
4. Agent proceeds based on feedback

**Generated agents work identically,** but human provides real-time feedback

**Command pattern:**
```bash
# Start HITL mode
/ralph-hitl
```

## PRD Workflow Integration

### PRD as Source of Truth

**Generated file:** `prd.json`

**Structure:**
```json
{
  "metadata": { "version": "1.0.0", ... },
  "goals": { "primaryGoal": "...", "objectives": [...] },
  "features": [
    {
      "id": "FEAT-001",
      "title": "...",
      "userStories": [...],
      "priority": "high",
      "acceptanceCriteria": [...]
    }
  ],
  "technical": { ... },
  "nonFunctional": { ... }
}
```

### PM Agent Uses PRD

**Scenario:** PM needs to assign feature implementation

**Workflow:**
```markdown
# PM reads PRD
Use read tool on prd.json

# Extract FEAT-001 requirements
{
  "id": "FEAT-001",
  "userStories": [...],
  "acceptanceCriteria": [...]
}

# Create task for developer
Write task to agents/developer/:
- Feature ID: FEAT-001
- User stories: [...]
- Acceptance criteria: [...]
- Dependencies: none
```

**Why this matters:** PRD provides structured, PM-quality requirements for task assignment

### Developer Agent Uses PRD

**Scenario:** Developer implements FEAT-001

**Workflow:**
```markdown
# Read assigned task
Task references FEAT-001

# Look up full requirements in PRD
Read prd.json, find FEAT-001

# Implement with full context
- User stories define "what" and "why"
- Acceptance criteria define "done"
- Technical requirements guide "how"
```

**Why this matters:** Developer has complete context without PM micromanagement

### QA Agent Uses PRD

**Scenario:** QA validates FEAT-001 implementation

**Workflow:**
```markdown
# Read PRD acceptance criteria
FEAT-001 acceptance criteria:
- User can login with email/password
- Invalid credentials show error message
- Successful login redirects to dashboard

# Create test cases from criteria
For each criterion, write test:
- Test login with valid credentials → success
- Test login with invalid credentials → error
- Verify dashboard redirect → success
```

**Why this matters:** QA has objective validation criteria from PM, not developer interpretation

### Updating PRD During Development

**Scenario:** New insights require PRD changes

**Workflow:**
1. **Discovery:** Agent encounters ambiguity or new requirement
2. **Escalation:** Agent asks PM for clarification
3. **PM updates PRD:** Edits prd.json with new information
4. **Notification:** PM notifies affected agents of PRD update
5. **Alignment:** Agents re-read PRD, adjust work accordingly

**Best practice:** Version PRD in git, agents reference specific version

```json
{
  "metadata": {
    "version": "1.1.0",  // Increment on changes
    "changelog": [
      {
        "version": "1.1.0",
        "date": "2026-02-08",
        "changes": "Added FEAT-005, clarified FEAT-001 acceptance criteria"
      }
    ]
  }
}
```

## Research Artifacts Integration

### Generated Research Summary

**File:** `docs/research-summary.md`

**Contents:**
- **Similar Projects:** 3-5 projects with architecture insights
- **Best Practices:** 5-10 practices for your category/tech stack
- **Q&A:** Clarifying questions and user answers

### When to Reference Research

**PM Agent:**
- **Task planning** - Check best practices for similar features
- **Architecture decisions** - Review similar project approaches
- **Risk assessment** - Learn from similar project pitfalls

**Developer Agent:**
- **Implementation patterns** - Follow best practices from research
- **Tech decisions** - Validate choices against similar projects
- **Troubleshooting** - Check how similar projects solved issues

**Example workflow:**
```markdown
# PM assigning authentication feature
Read docs/research-summary.md for authentication best practices

Research shows:
- Use bcrypt for password hashing (similar projects)
- Implement rate limiting (best practice)
- Add MFA support early (avoid refactoring later)

Create task incorporating these insights
```

### Updating Research Post-Wizard

**Scenario:** Project evolves, new research needed

**Manual process:**
1. Invoke `pm-research-specialist` subagent directly
2. Provide updated context (new features, tech stack changes)
3. Subagent generates new research findings
4. Append to or replace `docs/research-summary.md`

**Command:**
```
Use pm-research-specialist subagent to research {new_topic} given {updated_context}
```

## GDD Artifacts Integration (Games)

### Generated GDD Files

**Files:**
- `docs/design/decision_log.md` - Design decisions (DEC-NNN)
- `docs/design/open_questions.md` - Unresolved questions (OQ-NNN)
- `docs/design/gdd.md` - Comprehensive GDD

### Game Designer Agent Uses GDD

**Scenario:** Implementing combat system

**Workflow:**
```markdown
# Check decision log for combat decisions
docs/design/decision_log.md:
- DEC-003: Turn-based combat with action points
- DEC-007: Rock-paper-scissors weapon triangle

# Check open questions
docs/design/open_questions.md:
- OQ-002: How many action points per turn?
- OQ-005: Should critical hits exist?

# If decided, implement per decisions
# If open question, facilitate design session to resolve
```

**Why this matters:** GDD prevents design inconsistencies and wasted work

### Resolving Open Questions

**Workflow:**
1. **Game Designer facilitates Thermite session** (multi-persona debate)
2. **Decision reached:** Document as DEC-NNN in decision_log.md
3. **Update GDD:** Incorporate decision into main GDD
4. **Close question:** Move OQ-NNN from open_questions.md to resolved section

**Command:**
```
Use gamedesigner-thermite-facilitator subagent to resolve OQ-002: action points per turn
```

### GDD Version Control

**Best practice:** Track GDD changes in git with meaningful commits

```bash
git add docs/design/decision_log.md
git commit -m "DEC-008: Decided on stamina-based action point system

Rationale: Adds strategic resource management layer
Contributors: Game Designer, Systems Designer
Implications: Affects UI, combat pacing, player progression"
```

## Configuration Management

### MCP Settings Updates

**Scenario:** Need to add new MCP server to existing agent

**File:** `.claude/settings.developer.json`

**Process:**
```json
{
  "mcpServers": {
    "gitkraken": { ... },
    "fetch": { ... },
    // Add new server
    "websearch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-web-search"]
    }
  }
}
```

**After edit:**
1. Restart agent sessions to pick up new config
2. Agent can now use websearch MCP tools

### Agent AGENT.md Updates

**Scenario:** Agent responsibilities expand

**File:** `agents/developer/AGENT.md`

**Process:**
1. Edit AGENT.md to add new responsibilities
2. Update skills section if new skills needed
3. Agent uses updated context in next invocation

**Example:**
```markdown
## Responsibilities

- Implement features from PRD with high code quality
- Write comprehensive tests (unit, integration, e2e)
- Perform code reviews for other agents  # New responsibility
- Maintain technical documentation
```

### Script Updates for New Agents

**Scenario:** Project needs new agent type mid-development

**Process:**
1. Create agent files manually or run wizard again
2. Update orchestration scripts:

**watchdog-event.ps1:**
```powershell
[ValidateSet("developer", "pm", "qa", "dataengineer")]  # Add dataengineer
```

**message-queue.ps1:**
```powershell
$validAgents = @("developer", "pm", "qa", "dataengineer")  # Add dataengineer
```

**ralph-event-session.ps1:**
```powershell
$agentDirs = @("developer", "pm", "qa", "dataengineer")  # Add dataengineer
```

3. Create `.claude/settings.dataengineer.json`
4. Restart watchdog to pick up changes

## Common Workflow Patterns

### Pattern 1: Feature Development (Event-Driven)

**Scenario:** Implement FEAT-001 from PRD

**Workflow:**
```
1. PM reads PRD, extracts FEAT-001
2. PM creates task: agents/developer/feat-001.request
3. Watchdog invokes Developer
4. Developer reads PRD for full context
5. Developer implements feature
6. Developer writes: agents/developer/feat-001.result
7. PM receives result, creates QA task
8. QA reads PRD acceptance criteria
9. QA validates against criteria
10. QA writes: agents/qa/feat-001-validation.result
11. PM reviews, merges or requests changes
```

**Commands:**
```powershell
# Start orchestration
/ralph-coordinator-event

# PM assigns in conversation
# Watchdog manages worker invocations automatically
```

### Pattern 2: Design Decision (Games, Sequential)

**Scenario:** Resolve OQ-002 about action points

**Workflow:**
```
1. PM identifies open question needs resolution
2. PM hands off to Game Designer
3. Game Designer runs Thermite session
4. Game Designer updates decision_log.md with DEC-008
5. Game Designer updates gdd.md with decision
6. Game Designer hands off to Systems Designer
7. Systems Designer implements balance based on DEC-008
8. Systems Designer hands back to PM
```

**Commands:**
```bash
# Start sequential orchestration
/ralph-coordinator-single

# PM includes handoff instructions in initial task
```

### Pattern 3: Research Update (HITL)

**Scenario:** New framework discovered, research needed

**Workflow:**
```
1. Human invokes pm-research-specialist directly
2. Subagent researches new framework
3. Subagent presents findings
4. Human reviews and approves  key insights
5. Human updates docs/research-summary.md
6. Human notifies PM agent of updated research
7. PM incorporates findings into future tasks
```

**Commands:**
```
Use pm-research-specialist subagent to research {framework} for {use_case}
```

## Codebase Management

### Directory Structure

**After PRD Starter generation:**
```
project-root/
├── .claude/
│   ├── agents/                    # Agent definitions
│   ├── commands/                  # Copied from Ralph Orchestra
│   ├── hooks/                     # Copied from Ralph Orchestra
│   ├── scripts/                   # Orchestration scripts
│   ├── session/                   # Runtime state
│   ├── skills/                    # Copied skills
│   └── templates/                 # Copied templates
├── agents/                        # Agent workspaces
│   ├── developer/
│   ├── pm/
│   └── qa/
├── docs/
│   ├── research-summary.md        # Generated research
│   └── design/                    # GDD files (games only)
│       ├── decision_log.md
│       ├── open_questions.md
│       └── gdd.md
├── prd.json                       # PRD source of truth
├── README.md                      # Generated project overview
├── CLAUDE.md                       # Project-specific Claude instructions
└── ... (your source code)
```

### What to Commit to Git

**Always commit:**
- `prd.json` - Source of truth for requirements
- `docs/research-summary.md` - Research artifacts
- `docs/design/*` - GDD files (games)
- Agent files: `agents/*/AGENT.md`, `agents/*/SKILLS.md`
- MCP settings: `.claude/settings.*.json`
- `README.md` and `CLAUDE.md`

**Never commit:**
- `.claude/session/*` - Runtime state and messages
- `agents/*/*.request` - Ephemeral task files
- `agents/*/*.result` - Ephemeral result files

**Consider .gitignore:**
```
.claude/session/
agents/*/*.request
agents/*/*.result
agents/*/*.json.tmp
```

### What to Update Manually

**Regular updates:**
- `prd.json` - As requirements evolve
- Agent AGENT.md files - As responsibilities change
- `docs/research-summary.md` - When new research done
- `docs/design/decision_log.md` - When decisions made (games)

**Rarely update:**
- `.claude/scripts/*` - Only for new orchestration features
- `.claude/commands/*` - Only for new slash commands
- `.claude/settings.*.json` - Only for new MCP servers

### Syncing with Ralph Orchestra Updates

**Scenario:** Ralph Orchestra releases new orchestration scripts

**Process:**
1. Review changelog for breaking changes
2. Backup current `.claude/scripts/`
3. Copy new scripts from Ralph Orchestra repo
4. Re-apply any custom modifications
5. Test orchestration still works
6. Commit updated scripts

**Best practice:** Document custom script modifications in `CLAUDE.md`

## Troubleshooting Common Issues

### Agent Can't Find PRD

**Symptom:** Agent asks "Where is the PRD?"

**Cause:** PRD path not in workspace or agent doesn't know to look

**Solution:**
1. Verify `prd.json` exists in project root
2. Update AGENT.md with PRD location: "PRD is located at `prd.json`"
3. Or create `.claude/skills/prd-location.md`:
```markdown
---
name: prd-location
description: PRD location for all agents
---
The PRD is located at `prd.json` in the project root.
```

### MCP Server Not Available

**Symptom:** Agent says "Tool X not available"

**Cause:** MCP server not configured for that agent

**Solution:**
1. Check `.claude/settings.{agent}.json` has the server
2. Add server if missing
3. Restart agent session

### Watchdog Not Detecting Agent

**Symptom:** Watchdog ignores tasks for custom agent

**Cause:** Agent not in ValidateSet in watchdog scripts

**Solution:**
1. Update `.claude/scripts/watchdog-event.ps1` ValidateSet
2. Update `.claude/scripts/message-queue.ps1` validAgents array
3. Restart watchdog

### Research/GDD Files Not Generated

**Symptom:** Phase 10 completes but docs/ files missing

**Cause:** Generator didn't call research/GDD generation methods, or data was empty

**Solution:**
1. Check state file has non-empty `researchData` or `gddData`
2. Verify generator bugs are fixed (see [PRD Starter](prd-starter.md#error-handling))
3. Re-run generator manually if needed

## Best Practices Summary

### Planning
- Start with PRD Starter for new projects
- Run research phase thoroughly - insights save time later
- Answer clarifying questions thoughtfully - affects architecture

### Development
- Agents should always reference PRD for requirements
- Update PRD when requirements change, notify affected agents
- Use GDD as source of truth for game design decisions

### Maintenance
- Version PRD in git with meaningful commits
- Document design decisions as DEC-NNN, not just in code
- Keep research summary updated when new patterns emerge

### Orchestration
- Event-driven for parallel work, sequential for linear workflows
- HITL for learning agent patterns before automation
- Restart orchestration sessions after config changes

## Related Documentation

- [PRD Starter Wizard](prd-starter.md) - Wizard phases and generated files
- [PRD Starter Templates](prd-starter-templates.md) - Template system and customization
- [Orchestration Modes](orchestration-modes.md) - Event-driven, Sequential, HITL details
- [Architecture](architecture.md) - How orchestration works under the hood
- [Configuration](configuration.md) - Agent and MCP configuration deep dive

---

*Last updated: 2026-02-08*
