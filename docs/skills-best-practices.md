# Skills Best Practices

> Reference guide for creating and using skills in Claude Code

## What Are Skills?

Skills extend Claude's capabilities through `SKILL.md` files with instructions. Claude uses skills when relevant, or you can invoke them directly with `/skill-name`.

**Key Benefits:**
- Reusable instructions and workflows
- Custom slash commands
- Team knowledge sharing (conventions, patterns, style guides)
- Domain knowledge injection
- Automated workflows with side effects

---

## Quick Start: Create Your First Skill

### Step 1: Create the Skill Directory

```bash
# Personal skill (all projects)
mkdir -p ~/.claude/skills/explain-code

# Project skill (current project only)
mkdir -p .claude/skills/explain-code
```

### Step 2: Write SKILL.md

Every skill needs a `SKILL.md` file with two parts:
1. **YAML frontmatter** (between `---` markers) - tells Claude when to use it
2. **Markdown content** - instructions Claude follows

```markdown
---
name: explain-code
description: Explains code with visual diagrams and analogies. Use when explaining how code works, teaching about a codebase, or when the user asks "how does this work?"
---

When explaining code, always include:

1. **Start with an analogy**: Compare the code to something from everyday life
2. **Draw a diagram**: Use ASCII art to show the flow, structure, or relationships
3. **Walk through the code**: Explain step-by-step what happens
4. **Highlight a gotcha**: What's a common mistake or misconception?

Keep explanations conversational. For complex concepts, use multiple analogies.
```

### Step 3: Test the Skill

```bash
# Let Claude invoke it automatically
How does this code work?

# Or invoke directly
/explain-code src/auth/login.ts
```

---

## Skill Directory Structure

Each skill is a directory with `SKILL.md` as the entrypoint:

```
my-skill/
├── SKILL.md           # Main instructions (required)
├── template.md        # Template for Claude to fill in
├── examples/
│   └── sample.md      # Example output showing expected format
└── scripts/
    └── validate.sh    # Script Claude can execute
```

**Best Practice:** Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files.

---

## Where Skills Live

| Location | Path | Scope | Priority |
|----------|------|-------|----------|
| Enterprise | See managed settings | All users in organization | 1 (highest) |
| Personal | `~/.claude/skills/<skill-name>/SKILL.md` | All your projects | 2 |
| Project | `.claude/skills/<skill-name>/SKILL.md` | This project only | 3 |
| Plugin | `<plugin>/skills/<skill-name>/SKILL.md` | Where plugin enabled | 4 (lowest) |

**Priority:** Higher locations override lower ones when names match. Plugin skills use `plugin-name:skill-name` namespace.

### Automatic Discovery in Nested Directories

When editing files in subdirectories (e.g., `packages/frontend/`), Claude Code automatically discovers skills from nested `.claude/skills/` directories. This supports monorepo setups where packages have their own skills.

---

## Frontmatter Reference

All fields are optional. Only `description` is recommended.

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Display name. Uses directory name if omitted. Lowercase letters, numbers, hyphens only (max 64 chars). |
| `description` | Recommended | What the skill does and when to use it. Claude uses this to decide when to apply the skill. |
| `argument-hint` | No | Hint shown during autocomplete. Example: `[issue-number]` or `[filename] [format]`. |
| `disable-model-invocation` | No | Set to `true` to prevent Claude from automatically loading this skill. Default: `false`. |
| `user-invocable` | No | Set to `false` to hide from `/` menu. Default: `true`. |
| `allowed-tools` | No | Tools Claude can use without asking when this skill is active. |
| `model` | No | Model to use when this skill is active (`sonnet`, `opus`, `haiku`). |
| `context` | No | Set to `fork` to run in a subagent context. |
| `agent` | No | Which subagent type to use when `context: fork` is set. |
| `hooks` | No | Hooks scoped to this skill's lifecycle. |

---

## Types of Skill Content

### Reference Content

Adds knowledge Claude applies to current work. Conventions, patterns, style guides.

```markdown
---
name: api-conventions
description: API design patterns for this codebase
---

When writing API endpoints:
- Use RESTful naming conventions
- Return consistent error formats
- Include request validation
```

**Best For:** Team conventions, coding standards, domain knowledge.

### Task Content

Step-by-step instructions for specific actions. Use `disable-model-invocation: true` for manual-only workflows.

```markdown
---
name: deploy
description: Deploy the application to production
context: fork
disable-model-invocation: true
---

Deploy the application:
1. Run the test suite
2. Build the application
3. Push to the deployment target
```

**Best For:** Deployments, commits, code generation - workflows with side effects.

---

## Control Who Invokes a Skill

| Frontmatter | You can invoke | Claude can invoke | When loaded into context |
|-------------|---------------|------------------|-------------------------|
| (default) | Yes | Yes | Description always in context, full skill loads when invoked |
| `disable-model-invocation: true` | Yes | No | Description not in context, full skill loads when you invoke |
| `user-invocable: false` | No | Yes | Description always in context, full skill loads when invoked |

### Use `disable-model-invocation: true` for:

- Workflows with side effects (deploy, commit, send message)
- Timing-sensitive operations you want to control
- Destructive operations

### Use `user-invocable: false` for:

- Background knowledge users shouldn't invoke directly
- Context-only information (e.g., `legacy-system-context`)

---

## Pass Arguments to Skills

Arguments are available via the `$ARGUMENTS` placeholder.

```markdown
---
name: fix-issue
description: Fix a GitHub issue
disable-model-invocation: true
---

Fix GitHub issue $ARGUMENTS following our coding standards.

1. Read the issue description
2. Understand the requirements
3. Implement the fix
4. Write tests
5. Create a commit
```

Usage: `/fix-issue 123`

### String Substitutions

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking the skill |
| `${CLAUDE_SESSION_ID}` | The current session ID (for logging, session-specific files) |

---

## Supporting Files

Reference supporting files from `SKILL.md` so Claude knows what each contains and when to load it.

```markdown
## Additional resources

- For complete API details, see [reference.md](reference.md)
- For usage examples, see [examples.md](examples.md)
```

**Best Practice:** Keep `SKILL.md` focused on essentials. Load reference material only when needed.

---

## Advanced Patterns

### Dynamic Context Injection

The `!`command`` syntax runs shell commands before the skill content is sent to Claude.

```markdown
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
allowed-tools: Bash(gh:*)
---

## Pull request context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
- Changed files: !`gh pr diff --name-only`

## Your task
Summarize this pull request...
```

When invoked:
1. Each `!`command`` executes immediately
2. Output replaces the placeholder
3. Claude receives the fully-rendered prompt with actual data

### Run Skills in a Subagent

Add `context: fork` to run a skill in isolation. The skill content becomes the prompt that drives the subagent.

```markdown
---
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
---

Research $ARGUMENTS thoroughly:

1. Find relevant files using Glob and Grep
2. Read and analyze the code
3. Summarize findings with specific file references
```

**Agent Options:**
- `Explore` - Read-only, optimized for codebase exploration (Haiku)
- `Plan` - Read-only, for planning research
- `general-purpose` - Full tools, capable (default)
- Custom subagents from `.claude/agents/`

### Restrict Tool Access

```markdown
---
name: safe-reader
description: Read files without making changes
allowed-tools: Read, Grep, Glob
---
```

---

## Restrict Claude's Skill Access

Control which skills Claude can invoke automatically.

### Disable All Skills

```json
// Add to deny rules in /permissions
Skill
```

### Allow or Deny Specific Skills

```json
// Allow only specific skills
Skill(commit)
Skill(review-pr:*)

// Deny specific skills
Skill(deploy:*)
```

**Syntax:** `Skill(name)` for exact match, `Skill(name:*)` for prefix match.

### Hide Individual Skills

Add `disable-model-invocation: true` to frontmatter. This removes the skill from Claude's context entirely.

**Note:** `user-invocable` only controls menu visibility, not Skill tool access. Use `disable-model-invocation: true` to block programmatic invocation.

---

## Best Practices

### 1. Write Clear Descriptions

```yaml
# Good - Clear and specific
description: Reviews code for quality, security, and maintainability. Use proactively after code changes.

# Bad - Too vague
description: Helps with code.
```

### 2. Use the Right Type for Your Content

| Content Type | Use | Recommended Settings |
|--------------|-----|----------------------|
| Reference knowledge | Team conventions, patterns | Default frontmatter |
| Task with side effects | Deploy, commit, migrations | `disable-model-invocation: true` |
| Background knowledge | Context-only info | `user-invocable: false` |
| Heavy computation | Data processing, visualization | `context: fork`, specify agent |

### 3. Keep SKILL.md Focused

- Under 500 lines
- Move reference material to supporting files
- Use clear section headers
- Include examples

### 4. Use Argument Hints

```yaml
argument-hint: [issue-number]
argument-hint: [filename] [format]
```

This helps users understand what arguments to pass.

### 5. Test Your Skills

1. Verify it appears in `What skills are available?`
2. Test automatic invocation with matching requests
3. Test direct invocation with `/skill-name`
4. Test with arguments if applicable

### 6. Consider Subagents for Expensive Operations

For tasks that produce large output or need isolation:
- Use `context: fork`
- Specify appropriate `agent`
- Consider model choice for cost control

---

## Troubleshooting

### Skill Not Triggering

1. Check description includes keywords users would naturally say
2. Verify skill appears in `What skills are available?`
3. Try rephrasing request to match description
4. Invoke directly with `/skill-name`

### Skill Triggers Too Often

1. Make description more specific
2. Add `disable-model-invocation: true` for manual-only use

### Claude Doesn't See All Skills

Skill descriptions are loaded into context. If you have many skills, they may exceed the character budget (default: 15,000 characters).

**Solution:** Run `/context` to check for warnings. Increase limit with:
```bash
export SLASH_COMMAND_TOOL_CHAR_BUDGET=30000
```

---

## Complete Examples

### Code Reviewer Skill

```markdown
---
name: code-reviewer
description: Expert code reviewer. Use proactively after code changes for quality, security, and maintainability feedback.
---

You are a senior code reviewer. When invoked:

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

### Deploy Skill (Manual Only)

```markdown
---
name: deploy
description: Deploy the application to production
disable-model-invocation: true
argument-hint: [environment]
---

Deploy $ARGUMENTS to production:

1. Run the test suite: `npm test`
2. Build the application: `npm run build`
3. Push to deployment target
4. Verify the deployment succeeded
5. Run smoke tests
```

### API Conventions Reference

```markdown
---
name: api-conventions
description: API design patterns and conventions for this codebase. Use when designing or implementing API endpoints.
---

## API Design Conventions

### RESTful Naming

- Use plural nouns for collections: `/users`, `/posts`
- Use kebab-case for resource IDs: `/users/123`
- Nest resources logically: `/users/123/posts/456`

### Response Format

Success:
```json
{
  "data": { ... },
  "meta": { "page": 1, "perPage": 20 }
}
```

Error:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": { ... }
  }
}
```

### Validation

- Validate all request input
- Return 400 for validation errors
- Include field-level error details
- Use consistent error codes

See [api-reference.md](api-reference.md) for complete endpoint documentation.
```

---

## Commands vs Skills

**Historical Note:** Custom slash commands (`.claude/commands/`) have been merged into skills. Both work the same way now.

| Aspect | Commands | Skills |
|--------|----------|--------|
| Location | `.claude/commands/review.md` | `.claude/skills/review/SKILL.md` |
| Slash command | `/review` | `/review` |
| Supporting files | No | Yes (directory structure) |
| Frontmatter | Yes | Yes (with additional fields) |
| Priority | Lower | Higher (skills take precedence) |

**Recommendation:** Use skills for new work. Existing command files keep working.

---

## References

- [Official Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Claude Code Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
- [Ralph Orchestra Architecture](./architecture.md)
- [Subagent Best Practices](./subagent-best-practices.md)
