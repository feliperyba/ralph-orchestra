# Agent Workflows

Complete workflow documentation for all agents in the Ralph Orchestra multi-agent autonomous development system.

## Quick Start

To create a new agent workflow:

1. Copy [`_template.md`](_template.md) to `{agent-name}.md`
2. Replace all `{{PLACEHOLDER}}` values with actual content
3. Follow the section guidelines below
4. Update [`index.md`](index.md) to link to your new workflow

## Template Usage Guide

### YAML Frontmatter

Every workflow should start with YAML frontmatter for automation:

```yaml
---
title: "Agent Name Workflow"
tagline: "Brief catchphrase in quotes"
version: "X.X"
agent_role: "Primary responsibility description"
agent_type: "worker"  # or "coordinator"
orchestration_modes: ["event-driven", "sequential", "hitl"]
---
```

### Section-by-Section Guide

#### 1. Title with Tagline

```markdown
# Agent Name Workflow

> "Catchphrase that summarizes the agent's purpose"
```

**Tips:**
- Tagline should be catchy and descriptive
- Use present tense ("Implements features", not "Will implement")

#### 2. Role Card Table

| Field | Description | Example |
|-------|-------------|---------|
| **Primary** | Core responsibility | Implement features from PRD tasks |
| **Cannot** | Explicit restrictions | Suppress errors, use `@ts-ignore` |
| **Works With** | Other agents | PM, Tech Artist, QA, Game Designer |
| **Startup** | Launch command | `/ralph-worker-event --agent developer` |
| **Version** | Current version | 3.0 |

#### 3. Overview Diagram

Create a visual flow using ASCII box characters:

```
─  horizontal line
│  vertical line
┌  top-left corner
┐  top-right corner
└  bottom-left corner
┘  bottom-right corner
├  left T (vertical branch)
┤  right T (vertical branch)
┼  cross (both branches)
```

**Example:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW NAME                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                            │
│  │  START   │───►│  ACTION  │───►│   END    │                            │
│  └──────────┘    └──────────┘    └──────────┘                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 4. Decision Framework

A state matrix showing all possible transitions:

| Column | Description |
|--------|-------------|
| Current State | State before trigger (code format) |
| Trigger | Event or condition causing transition |
| Action | What the agent does |
| Next State | Resulting state (code format) |

**Tips:**
- List ALL possible states and transitions
- Use code format for state names (`state_name`)
- Include error/blocked states

#### 5. Startup Sequence

Numbered steps showing agent initialization:

```markdown
1. Read prd.json for current task

2. ⚠️ SKILL CHECK - Match task to skill

3. ⚠️ TASK RESEARCH (MANDATORY)
   ┌───────────────────────────────────────────────────────────────────┐
   │  Task("subagent", { prompt: "...", timeout: 300000 })            │
   └───────────────────────────────────────────────────────────────────┘
```

**Conventions:**
- Use `⚠️` for mandatory or critical steps
- Use boxed ASCII for code blocks within lists
- Include timeout values for Task invocations

#### 6. Task/Asset Type to Skill Mapping

Table mapping work types to skills:

| Column | Description |
|--------|-------------|
| Item Type | Category of work (e.g., R3F Scene, Physics) |
| Skill(s) to Use | Skill name to invoke |
| Sub-Agent | Task sub-agent if applicable (or `-`) |

#### 7. Workflow Flow

Detailed step-by-step process with nested ASCII boxes:

```markdown
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW FLOW                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  1. STEP TITLE (MANDATORY)                                          │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Description and details...                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                            │
│                              ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  2. NEXT STEP                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 8. Sub-Agents Reference

Table of Task sub-agents the agent invokes:

| Column | Description |
|--------|-------------|
| Sub-Agent | Name (used in Task() call) |
| Model | AI model (Sonnet, Haiku, Inherit) |
| Purpose | What it does |

**Include invocation format:**
```markdown
Invocation: Task("subagent-name", { prompt: "...", timeout: 300000 })
```

#### 9. Skills Reference

Table of skills the agent uses directly:

| Column | Description |
|--------|-------------|
| Skill | Skill name (used in Skill() call) |
| Purpose | Brief description |

#### 10. Commit Format

Code block showing the standard commit message:

```markdown
[ralph] [agent] {TASK_ID}: Brief description

- Change 1
- Change 2

PRD: {TASK_ID} | Agent: agent | Iteration: N
```

#### 11. Mandatory Pre-Commit Checklist

Categorized checklist using checkboxes:

```markdown
┌─────────────────────────────────────────────────────────────────────────────┐
│                  MANDATORY PRE-COMMIT CHECKLIST                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Code Quality                                                        │   │
│  │  ☑ No any types without justification                              │   │
│  │  ☑ No @ts-ignore or @ts-expect-error                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Checkbox conventions:**
- `☑` - Completed/Required item
- `☐` - Optional item
- `✅` - Success criterion
- `❌` - Failure criterion

#### 12. Exit Conditions

Boxed list of conditions before agent exits:

```markdown
⚠️ BEFORE exiting, you MUST:
  1. Condition 1
  2. Condition 2
  3. Condition 4
  4. ONLY THEN exit
```

#### 13. File Permissions

Clear separation of writable and restricted paths:

```markdown
MAY write to:
  • path/to/writable/files
  • another/path

MAY NOT write to:
  • restricted/path
  • another/restricted/path
```

#### 14. Messages You Send/Receive

Table of event messages:

| Column | Description |
|--------|-------------|
| Event | What event triggers the message |
| Type | Message type identifier |
| To/From | Target/Source agent |
| Priority | Message priority level |

#### 15. See Also

Cross-references to related documentation:

```markdown
- [Development Cycle](./development-cycle.md) - Complete task lifecycle
- [PM Coordinator](./pm-coordinator.md) - Task assignment workflow
- [QA Workflow](./qa.md) - Validation pipeline
```

## Style Conventions

### Icons

| Icon | Usage |
|------|-------|
| `⚠️` | Warnings, mandatory steps |
| `✅` | Success criteria, allowed items |
| `❌` | Failure criteria, prohibited items |
| `☑` | Checked/required checklist items |
| `☐` | Optional checklist items |
| `►` | Flow arrows in diagrams |
| `│` | Vertical connectors |
| `─` | Horizontal lines |

### Code Blocks

Use for:
- Commands
- JSON examples
- File paths
- Code snippets

### Tables

Use pipe-delimited tables for:
- Mappings (type → skill)
- Reference data (sub-agents, skills)
- Decision matrices
- Message formats

## Available Workflow Documents

### General Development Cycle
- **[Development Cycle](./development-cycle.md)** - Complete task lifecycle from assignment to completion

### Agent-Specific Workflows
- **[PM Coordinator](./pm-coordinator.md)** - Task assignment, progress monitoring, retrospectives
- **[Developer](./developer.md)** - Feature implementation, research patterns, feedback loops
- **[Tech Artist](./techartist.md)** - Asset creation, shaders, visual testing
- **[QA Validator](./qa.md)** - Validation pipeline, browser testing, bug reporting
- **[Game Designer](./gamedesigner.md)** - GDD creation, design questions, playtesting

## Quick Reference

### Task Status Lifecycle

```
┌──────────┐    ┌──────────┐    ┌──────────────┐    ┌──────────┐    ┌──────────┐
│  PENDING  │───►│ ASSIGNED │───►│ AWAITING_QA  │───►│ COMPLETED│───►│ ARCHIVED │
└──────────┘    └──────────┘    └──────────────┘    └──────────┘    └──────────┘
                      │                                  ▲
                      │                                  │
                      ▼                                  │
                 ┌──────────┐                           │
                 │ IN_PROGRESS│──────────────────────────┘
                 └──────────┘     (worker self-report)

                      │
                      ▼
                 ┌──────────┐
                 │ NEEDS_FIXES│
                 └──────────┘
                      │
                      └──────────► (reassign to worker)
```

### Priority Order (Task Selection)

```
TIER_0_BLOCKER (1) ──► Architectural blockers
TIER_1_FOUNDATION (2) ──► Core systems, must launch
TIER_2_ECONOMY (3)     ──► Economy and gameplay
TIER_3_SUPPORT (4)     ──► Support and map features
TIER_4_VALIDATION (5)  ──► E2E tests
TIER_5_MOVEMENT (6)    ──► Movement polish
TIER_6_UI (7)          ──► UI polish
TIER_7_LOW (8)         ──► Low priority polish
```

### Category to Agent Mapping

```
CATEGORY               │ DEFAULT AGENT
───────────────────────┼────────────────
architectural          │ developer
functional             │ developer
integration            │ developer
visual                 │ techartist
shader                 │ techartist
polish                 │ techartist
ui                     │ techartist
```

## See Also

- [Architecture Documentation](../core/architecture.md) - System architecture overview
- [Configuration Guide](../core/configuration.md) - PRD format and agent settings
- [Skills Best Practices](../best-practices/skills-best-practices.md) - Creating and maintaining skills
