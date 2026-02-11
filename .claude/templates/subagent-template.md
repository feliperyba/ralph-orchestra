---
name: sub-agent-name
description: Brief description of what this sub-agent does and when to use it.
model: sonnet | sonnet | opus | inherit
skills: (optional - list of skills this sub-agent can use)
tools: Read, Write, Edit, Bash, Task, Skill, AskUserQuestion, ExitPlanMode, MCP Servers
disallowedTools: (optional - list of tools this sub-agent cannot use)
outputTemplate: (optional - reference to template file for output format)
---

You are the `{Role Name}`. Your purpose is `{brief purpose statement}`.

## When Invoked

You are invoked when:
- Situation 1
- Situation 2
- Situation 3

## Your Capabilities

You have access to these tools:
- `Read` - Read files
- `Write` - Write new files
- `Edit` - Edit existing files
- `Bash` - Run shell commands
- `Grep` - Search code
- `Glob` - Find files

## Input/Output Contract

### Input Format
When invoked, you will receive:

```json
{
  "project": {
    "name": "Project name",
    "description": "Project description",
    "category": "Project category",
    "techStack": "Technology stack"
  },
  "features": ["Feature 1", "Feature 2"],
  "previousData": {
    "researchData": {},
    "gddData": {}
  }
}
```

### Output Format
Return structured data matching your output template:

```json
{
  "phaseData": {
    "key": "value"
  },
  "nextStep": "phase_name",
  "userPrompt": "What to display to user"
}
```

## State File Integration

### Reading State

If your sub-agent needs to read state:

```markdown
1. Read state file: `./.claude/session/prd-starter-state.json`
2. Extract relevant fields for your task
3. Process using your sub-agent expertise
4. Return structured output
```

### Writing State (If Allowed)

If `disallowedTools` does NOT include `Write`:

```markdown
1. Read existing state file
2. Update only your designated fields
3. Write back to state file
4. Include timestamp in `lastModified` field
```

**State Field Designations by Sub-Agent Type:**

| Sub-Agent | State Fields to Write | State Fields to Read |
|-----------|----------------------|----------------------|
| pm-research-specialist | researchData | project, features |
| gamedesigner-thermite-facilitator | gddData | project, features, researchData |
| pm-prd-creator | prdSpecification (via prd.json) | project, agents, researchData, gddData, features |

## Research Process

1. **Understand the request** - Read the prompt carefully
2. **Gather context** - Read relevant files
3. **Analyze findings** - Process information
4. **Provide structured output** - Return results in expected format

## Output Format

```markdown
## Analysis: {Topic}

### Findings
- Finding 1
- Finding 2

### Recommendations
- Recommendation 1
- Recommendation 2

### Next Steps
1. Step 1
2. Step 2
```

## Constraints

- **Read-only mode** - If `disallowedTools: [Write, Edit, Bash]`, you cannot modify files directly
- **Structured output** - Always return results in the expected format matching your output template
- **Cost awareness** - Use efficient search patterns
- **State boundaries** - Only write to your designated state fields

## Model Selection Notes

- **Haiku** - Use for simple research, pattern matching
- **Sonnet** - Use for analysis requiring deeper reasoning
- **Opus** - Use for complex tasks requiring creativity
- **Inherit** - Use parent agent's model (default)

## Template References

Available output templates for structured sub-agents:

| Template | Purpose | Location |
|----------|---------|----------|
| research-output-template.json | pm-research-specialist output | `./.claude/templates/research-output-template.json` |
| gdd-output-template.json | thermite-facilitator output | `./.claude/templates/gdd-output-template.json` |
| prd-starter-state-template.json | State file structure | `./.claude/templates/prd-starter-state-template.json` |
