# Subagent Best Practices

> Reference guide for creating and using subagents in Claude Code

## What Are Subagents?

Subagents are specialized AI assistants that handle specific types of tasks. Each subagent runs in its own context window with:
- Custom system prompt
- Specific tool access
- Independent permissions

## Benefits of Subagents

| Benefit | Description |
|---------|-------------|
| **Preserve Context** | Keep exploration and implementation out of main conversation |
| **Enforce Constraints** | Limit which tools a subagent can use |
| **Reuse Configurations** | Share subagents across projects via user-level agents |
| **Specialize Behavior** | Focused system prompts for specific domains |
| **Control Costs** | Route tasks to faster, cheaper models (Haiku) |

---

## Quick Start: Subagent Structure

Subagents are defined in Markdown files with YAML frontmatter:

```markdown
---
name: code-reviewer
description: Expert code reviewer. Use proactively after code changes.
tools: Read, Glob, Grep, Bash
model: sonnet
---

You are a senior code reviewer. When invoked, analyze the code and provide
specific, actionable feedback on quality, security, and best practices.
```

---

## Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier using lowercase letters and hyphens |
| `description` | Yes | When Claude should delegate to this subagent. **Include "use proactively"** |
| `tools` | No | Tools the subagent can use. Inherits all if omitted |
| `disallowedTools` | No | Tools to deny, removed from inherited or specified list |
| `model` | No | Model: `sonnet`, `opus`, `haiku`, or `inherit`. Defaults to `inherit` |
| `permissionMode` | No | Permission mode: `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `skills` | No | Skills to preload into subagent context at startup |
| `hooks` | No | Lifecycle hooks scoped to this subagent |

---

## Model Selection Guidelines

| Model | When to Use | Cost | Speed |
|-------|-------------|------|-------|
| `haiku` | Read-only research, code review, simple validation | Low | Fastest |
| `sonnet` | Most implementation tasks, capable work | Medium | Medium |
| `opus` | Complex architecture, debugging, creative work | High | Slower |
| `inherit` | Use same model as main conversation | Varies | Varies |

**Best Practice:** Use Haiku for read-only tasks (code-research, code-review) to minimize costs.

---

## Subagent Scope & Priority

| Location | Scope | Priority | Use Case |
|----------|-------|----------|----------|
| `--agents` CLI flag | Current session | 1 (highest) | Quick testing, automation |
| `./.claude/agents/` | Current project | 2 | Project-specific agents (version control) |
| `~/./.claude/agents/` | All your projects | 3 | Personal reusable agents |
| Plugin's `agents/` | Where plugin enabled | 4 (lowest) | Distributed via plugins |

**Best Practice:**
- Use `./.claude/agents/` for project-specific subagents (team collaboration)
- Use `~/./.claude/agents/` for personal reusable subagents

---

## Tool Access Patterns

### Allowlist Pattern (Recommended)

```yaml
---
name: safe-researcher
description: Read-only codebase research
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
---
```

### Read-Only Database Pattern with Hooks

```yaml
---
name: db-reader
description: Execute read-only database queries
tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly-query.sh"
---
```

Validation script (`./scripts/validate-readonly-query.sh`):

```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Block SQL write operations (case-insensitive)
if echo "$COMMAND" | grep -iE '\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE)\b' > /dev/null; then
  echo "Blocked: Only SELECT queries are allowed" >&2
  exit 2
fi

exit 0
```

---

## Permission Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| `default` | Standard permission checking with prompts | Most subagents |
| `acceptEdits` | Auto-accept file edits | Trusted refactoring agents |
| `dontAsk` | Auto-deny permission prompts | Read-only validation |
| `bypassPermissions` | Skip all permission checks | Automated CI/CD |
| `plan` | Plan mode (read-only exploration) | Planning/research agents |

---

## Preloading Skills

Use the `skills` field to inject domain knowledge at startup:

```yaml
---
name: api-developer
description: Implement API endpoints following team conventions
skills:
  - api-conventions
  - error-handling-patterns
---

Implement API endpoints. Follow the conventions and patterns from the preloaded skills.
```

**Important:** Subagents don't inherit skills from the parent conversation; you must list them explicitly. The full content of each skill is injected into the subagent's context.

---

## Description Best Practices

The `description` field controls when Claude delegates to your subagent.

### Do's

```yaml
# Good - Clear and proactive
description: Expert code reviewer. Use proactively after code changes.

# Good - Specific trigger
description: Debugging specialist. Use when encountering errors or test failures.

# Good - Task-specific
description: Database analyst for read-only SELECT queries and reporting.
```

### Don'ts

```yaml
# Bad - Too vague
description: Helps with code.

# Bad - Missing proactive trigger
description: Code review agent.

# Bad - No clear use case
description: A helpful assistant.
```

**Key Pattern:** Include "Use proactively" or specific trigger conditions in the description.

---

## Common Patterns

### 1. Isolate High-Volume Operations

Use subagents for tasks that produce large amounts of output:

```yaml
---
name: test-runner
description: Run test suite and report failures. Use proactively after code changes.
tools: Bash
model: haiku
---

Run the test suite and report only failing tests with their error messages.
```

### 2. Parallel Research

Spawn multiple subagents for independent investigations:

```yaml
# agent-1: authentication-researcher
# agent-2: database-researcher
# agent-3: api-researcher
```

Each explores its area independently, then Claude synthesizes findings.

### 3. Chain Subagents

Use subagents in sequence for multi-step workflows:

```
code-reviewer → finds issues → optimizer → fixes issues
```

### 4. Read-Only Review

```yaml
---
name: code-reviewer
description: Expert code review specialist. Use immediately after writing code.
tools: Read, Grep, Glob, Bash
model: haiku
---

You are a senior code reviewer. Focus on:
- Code clarity and readability
- Security vulnerabilities
- Error handling
- Test coverage
- Performance considerations

Organize feedback by priority:
1. Critical issues (must fix)
2. Warnings (should fix)
3. Suggestions (nice to have)
```

---

## Built-in Subagents

| Agent | Model | Tools | Purpose |
|-------|-------|-------|---------|
| **Explore** | Haiku | Read-only | File discovery, codebase exploration |
| **Plan** | Inherit | Read-only | Research during plan mode |
| **general-purpose** | Inherit | All tools | Complex multi-step tasks |
| **Bash** | Inherit | All tools | Terminal commands in separate context |
| **claude-code-guide** | Haiku | Varies | Answer questions about Claude Code |

**Best Practice:** Don't override built-in agent names. Use descriptive unique names for custom agents.

---

## When to Use Subagents vs Main Conversation

### Use Main Conversation When:

- Task needs frequent back-and-forth or iterative refinement
- Multiple phases share significant context (planning → implementation → testing)
- Making a quick, targeted change
- Latency matters (subagents start fresh)

### Use Subagents When:

- Task produces verbose output you don't need in main context
- You want to enforce specific tool restrictions or permissions
- Work is self-contained and can return a summary
- You want to use a cheaper model (Haiku) for cost savings

### Consider Skills When:

- You want reusable prompts/workflows in the main conversation context
- You don't need isolated context

---

## Resuming Subagents

Each subagent invocation creates a new instance with fresh context. To continue existing work:

```
Use the code-reviewer subagent to review the auth module
[Agent completes]

Continue that code review and now analyze the authorization logic
[Claude resumes the subagent with full context]
```

**Benefits of resuming:**
- Retains full conversation history
- All previous tool calls and results preserved
- Picks up exactly where it stopped

---

## Hooks in Subagents

### Frontmatter Hooks

```yaml
---
name: code-reviewer
description: Review code with automatic linting
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-command.sh $TOOL_INPUT"
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "./scripts/run-linter.sh"
---
```

### Hook Events

| Event | Matcher Input | When it Fires |
|-------|---------------|---------------|
| `PreToolUse` | Tool name | Before the subagent uses a tool |
| `PostToolUse` | Tool name | After the subagent uses a tool |
| `Stop` | (none) | When the subagent finishes |

### Project-Level Hooks

Configure in `settings.json` for subagent lifecycle events:

```json
{
  "hooks": {
    "SubagentStart": [
      {
        "matcher": "db-agent",
        "hooks": [
          { "type": "command", "command": "./scripts/setup-db.sh" }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "db-agent",
        "hooks": [
          { "type": "command", "command": "./scripts/cleanup-db.sh" }
        ]
      }
    ]
  }
}
```

---

## Disabling Subagents

Prevent Claude from using specific subagents in settings:

```json
{
  "permissions": {
    "deny": ["Task(Explore)", "Task(my-custom-agent)"]
  }
}
```

Or via CLI:

```bash
claude --disallowedTools "Task(Explore)"
```

---

## Complete Example: Code Reviewer

```markdown
---
name: code-reviewer
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code.
tools: Read, Grep, Glob, Bash
model: inherit
---

You are a senior code reviewer ensuring high standards of code quality and security.

When invoked:
1. Run git diff to see recent changes
2. Focus on modified files
3. Begin review immediately

Review checklist:
- Code is clear and readable
- Functions and variables are well-named
- No duplicated code
- Proper error handling
- No exposed secrets or API keys
- Input validation implemented
- Good test coverage
- Performance considerations addressed

Provide feedback organized by priority:
- Critical issues (must fix)
- Warnings (should fix)
- Suggestions (consider improving)

Include specific examples of how to fix issues.
```

---

## Complete Example: Debugger

```markdown
---
name: debugger
description: Debugging specialist for errors, test failures, and unexpected behavior. Use proactively when encountering any issues.
tools: Read, Edit, Bash, Grep, Glob
---

You are an expert debugger specializing in root cause analysis.

When invoked:
1. Capture error message and stack trace
2. Identify reproduction steps
3. Isolate the failure location
4. Implement minimal fix
5. Verify solution works

Debugging process:
- Analyze error messages and logs
- Check recent code changes
- Form and test hypotheses
- Add strategic debug logging
- Inspect variable states

For each issue, provide:
- Root cause explanation
- Evidence supporting the diagnosis
- Specific code fix
- Testing approach
- Prevention recommendations

Focus on fixing the underlying issue, not the symptoms.
```

---

## References

- [Official Claude Code Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Ralph Orchestra Architecture](../core/architecture.md)
- [Agent Configuration](../.././.claude/agents/)
