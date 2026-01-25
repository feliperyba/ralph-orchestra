# Sub-Agent Guidelines

Developer agent sub-agents for specialized work.

## Sub-Agent Overview

| Sub-Agent | Model | Purpose | When to Invoke |
|-----------|-------|---------|----------------|
| orchestrator | Sonnet | Routes work to specialists | Start of complex tasks |
| code-research | Haiku | Research existing patterns | **MANDATORY before all coding** |
| implementation | Sonnet | Implement features using R3F/TypeScript | After research completes |
| validation | Haiku | Run type-check, lint, test, build | **MANDATORY before commit** |
| commit | Haiku | Handle commits, PRD updates, messaging | After validation passes |

## Invocation Pattern

```javascript
Task({
  subagent_type: "developer-{subagent-name}",
  description: "{brief description}",
  prompt: "{detailed prompt}",
  timeout: 300000  // 5 minutes
})
```

## 1. Orchestrator Sub-Agent

**Model:** Sonnet
**Purpose:** Analyzes task and delegates to appropriate sub-agents

**When to use:**
- Complex tasks with multiple components
- Tasks requiring multiple skills
- Unclear which specialist should handle the work

**Example:**
```javascript
Task({
  subagent_type: "developer-orchestrator",
  description: "Implement shooting mechanics with prediction",
  prompt: "Analyze this task and delegate to appropriate specialists: implement server-authoritative shooting with client-side prediction"
})
```

**Orchestrator flow:**
1. Analyze task requirements
2. Identify required skills
3. Invoke code-research first
4. Invoke implementation with research findings
5. Invoke validation
6. Invoke commit

## 2. Code-Research Sub-Agent (MANDATORY)

**Model:** Haiku
**Purpose:** Research existing codebase patterns before coding

**When to use:**
- **ALWAYS before writing any code**
- Finding existing implementations
- Understanding codebase conventions
- Locating similar features

**Example:**
```javascript
Task({
  subagent_type: "developer-code-research",
  description: "Research movement patterns",
  prompt: "Research existing player movement patterns in the codebase. Find how WASD controls are implemented, how velocity is handled, and how the state is updated.",
  timeout: 300000
})
```

**Research output should include:**
- Relevant file paths
- Code examples
- Implementation patterns
- Dependencies to add
- Files to modify

**Why Haiku:** Fast, cost-effective for read-only exploration

## 3. Implementation Sub-Agent

**Model:** Sonnet
**Purpose:** Implement features using R3F/TypeScript

**When to use:**
- After code-research completes
- Writing new code
- Modifying existing code
- Creating components/hooks/stores

**Example:**
```javascript
Task({
  subagent_type: "developer-implementation",
  description: "Implement player controller",
  prompt: "Based on research findings, implement WASD player controller with velocity-based movement. Follow existing patterns found in src/components/player/",
  timeout: 600000
})
```

**Why Sonnet:** Capable of writing correct TypeScript/R3F code

## 4. Validation Sub-Agent (MANDATORY)

**Model:** Haiku
**Purpose:** Run feedback loops and quality checks

**When to use:**
- **Before every commit**
- After implementation completes
- After bug fixes
- Before sending to QA

**Example:**
```javascript
Task({
  subagent_type: "developer-validation",
  description: "Validate player controller",
  prompt: "Run full validation: type-check, lint, test, build. Report all failures and fix them.",
  timeout: 300000
})
```

**Validation sequence:**
1. `npm run type-check` - Must have 0 errors
2. `npm run lint` - Must have 0 warnings
3. `npm run test` - All must pass
4. `npm run build` - Must succeed

**Why Haiku:** Validation is straightforward, Haiku is cost-effective

## 5. Commit Sub-Agent

**Model:** Haiku
**Purpose:** Handle commits, PRD updates, messaging

**When to use:**
- After validation passes
- Before sending work to QA
- Before exiting

**Example:**
```javascript
Task({
  subagent_type: "developer-commit",
  description: "Commit player controller",
  prompt: "Commit changes with Ralph format, update PRD status, send message to QA, push to developer-worktree branch",
  timeout: 120000
})
```

**Commit flow:**
1. `git add .`
2. `git commit -m "[ralph] [developer] feat-XXX: description"`
3. `git push origin developer-worktree`
4. Update `prd.json.items[{taskId}].status = "awaiting_qa"`
5. Send `implementation_complete` message to QA
6. Update `prd.json.agents.developer.status = "idle"`

## Sub-Agent Coordination Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    TASK ASSIGNED                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   ORCHESTRATOR       │  (Optional - for complex tasks)
              │   (Sonnet)            │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   CODE-RESEARCH      │  ◀─── MANDATORY
              │   (Haiku)            │
              └──────────┬───────────┘
                         │
                    [Finds patterns]
                         │
                         ▼
              ┌──────────────────────┐
              │  IMPLEMENTATION      │
              │   (Sonnet)           │
              └──────────┬───────────┘
                         │
                    [Writes code]
                         │
                         ▼
              ┌──────────────────────┐
              │    VALIDATION        │  ◀─── MANDATORY
              │   (Haiku)            │
              └──────────┬───────────┘
                         │
                    [Fixes until pass]
                         │
                         ▼
              ┌──────────────────────┐
              │      COMMIT          │
              │   (Haiku)            │
              └──────────┬───────────┘
                         │
                    [Updates PRD]
                    [Sends to QA]
                    [Exits]
```

## Sub-Agent Communication

Sub-agents communicate through:
1. **Task prompt** - Input parameters
2. **Task return value** - Research findings, validation results
3. **prd.json** - Task status, agent status
4. **Message queue** - Inter-agent messages

## Error Handling

| Situation | Action |
|-----------|--------|
| Research fails | Send question to PM, set status to `awaiting_pm` |
| Implementation blocked | Document in PRD notes, send question to PM |
| Validation fails | Fix issues, re-run validation |
| Commit fails | Check git status, resolve conflicts, retry |

## Sub-Agent Best Practices

1. **Always invoke code-research first** - Never skip research
2. **Always invoke validation before commit** - No exceptions
3. **Use Haiku for read-only tasks** - Cost-effective for research, validation
4. **Use Sonnet for code generation** - Better TypeScript quality
5. **Timeouts matter** - Set appropriate timeouts for each sub-agent
6. **Context handoff** - Each sub-agent should document progress for the next

## Sub-Agent Timeout Guidelines

| Sub-Agent | Suggested Timeout | Reason |
|-----------|-------------------|--------|
| orchestrator | 600000 (10 min) | May need to analyze complex requirements |
| code-research | 300000 (5 min) | Read-only should be fast |
| implementation | 600000 (10 min) | Writing code takes time |
| validation | 300000 (5 min) | Running checks is straightforward |
| commit | 120000 (2 min) | Git operations are quick |
