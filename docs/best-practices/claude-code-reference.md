# Claude Code Reference Guide

> A CLI-focused reference guide combining content from [common-workflows](https://code.claude.com/docs/en/common-workflows) and [best-practices](https://code.claude.com/docs/en/best-practices).

## Introduction

**Claude Code** is an agentic coding environment. Unlike a chatbot that answers questions and waits, Claude Code can read your files, run commands, make changes, and autonomously work through problems while you watch, redirect, or step away entirely.

This changes how you work. Instead of writing code yourself and asking Claude to review it, you describe what you want and Claude figures out how to build it. Claude explores, plans, and implements.

### Core Constraint: Context Window Management

Claude's context window holds your entire conversation, including every message, every file Claude reads, and every command output. This can fill up fast, and LLM performance degrades as context fills. When the context window is getting full, Claude may start "forgetting" earlier instructions or making more mistakes.

The context window is the most important resource to manage.

---

## Common Workflows

### Understanding New Codebases

When joining a new project, start with a quick codebase overview. Ask Claude to:
- Get a quick codebase overview
- Find relevant code related to a specific feature or functionality

Example prompts:
```
Give me a quick overview of this codebase's structure and main components.
```

```
Find all code related to user authentication.
```

### Fixing Bugs Efficiently

When you encounter an error message and need to find and fix its source, provide the error with context about the symptom and where to look.

### Refactoring Code

When updating old code to use modern patterns and practices, let Claude analyze the existing code first, then plan the refactoring approach.

### Working with Tests

Claude can generate tests that follow your project's existing patterns and conventions. When asking for tests, be specific about what behavior you want to verify. Claude examines your existing test files to match the style, frameworks, and assertion patterns already in use.

For comprehensive coverage, ask Claude to identify edge cases you might have missed. Claude can analyze your code paths and suggest tests for error conditions, boundary values, and unexpected inputs.

### Creating Pull Requests

Use the `gh` CLI tool for creating pull requests. Claude knows how to use it for creating issues, opening pull requests, and reading comments. Without `gh`, Claude can still use the GitHub API, but unauthenticated requests often hit rate limits.

### Handling Documentation

Ask Claude to add or update documentation for your code. Be specific about what sections need updates and the target audience.

### Working with Images

You can provide images directly in prompts by copy/pasting or dragging and dropping. Claude can analyze image content to help with UI implementation, error diagnosis, and design verification.

### Referencing Files and Directories with @

Use `@` to quickly include files or directories without waiting for Claude to read them. Claude reads the referenced file before responding.

```
Look at @src/auth/login.ts and explain how token refresh works.
```

### Using Specialized Subagents

Subagents run in their own context with their own set of allowed tools. They're useful for tasks that read many files or need specialized focus without cluttering your main conversation.

Tell Claude to use subagents explicitly:
```
Use a subagent to review this code for security issues.
```

```
Use subagents to investigate how our authentication system handles token refresh.
```

---

## Best Practices

### Verification Strategies

Claude performs dramatically better when it can verify its own work, like run tests, compare screenshots, and validate outputs. Without clear success criteria, it might produce something that looks right but actually doesn't work.

**Provide Verification Criteria**

| Before | After |
|--------|-------|
| "implement a function that validates email addresses" | "write a validateEmail function. example test cases: [email protected] is true, invalid is false, [email protected] is false. run the tests after implementing" |
| "make the dashboard look better" | "[paste screenshot] implement this design. take a screenshot of the result and compare it to the original. list differences and fix them" |
| "the build is failing" | "the build fails with this error: [paste error]. fix it and verify the build succeeds. address the root cause, don't suppress the error" |

**Invest in rock-solid verification**: Your verification can be a test suite, a linter, or a Bash command that checks output.

### Workflow: Explore → Plan → Code

Letting Claude jump straight to coding can produce code that solves the wrong problem. The recommended workflow has four phases:

1. **Explore** - Understand the codebase and problem space
2. **Plan** - Design the implementation approach
3. **Code** - Implement the solution
4. **Verify** - Test and validate the implementation

Use Plan Mode to separate exploration from execution (see CLI Usage Patterns below).

### Prompting Strategies

Claude can infer intent, but it can't read your mind. Reference specific files, mention constraints, and point to example patterns.

| Strategy | Before | After |
|----------|--------|-------|
| **Scope the task** | "add tests for foo.py" | "write a test for foo.py covering the edge case where the user is logged out. avoid mocks." |
| **Point to sources** | "why does ExecutionFactory have such a weird api?" | "look through ExecutionFactory's git history and summarize how its api came to be" |
| **Reference patterns** | "add a calendar widget" | "look at how existing widgets are implemented on the home page to understand the patterns. HotDogWidget.php is a good example. follow the pattern to implement a new calendar widget..." |
| **Describe the symptom** | "fix the login bug" | "users report that login fails after session timeout. check the auth flow in src/auth/, especially token refresh..." |

### Providing Rich Context

You can provide rich data to Claude in several ways:

- **Reference files with `@`** instead of describing where code lives
- **Paste images directly** - copy/paste or drag and drop
- **Give URLs** for documentation and API references
- **Pipe in data** by running `cat error.log | claude`
- **Let Claude fetch what it needs** - tell Claude to pull context itself using Bash commands, MCP tools, or by reading files

### Communication Tips

**Asking Codebase Questions**

When onboarding to a new codebase, use Claude Code for learning and exploration. You can ask Claude the same sorts of questions you would ask another engineer:

- How does logging work?
- How do I make a new API endpoint?
- What does `async move { ... }` do on line 134 of `foo.rs`?
- What edge cases does `CustomerOnboardingFlowImpl` handle?
- Why does this code call `foo()` instead of `bar()` on line 333?

**Let Claude Interview You**

Claude asks about things you might not have considered yet, including technical implementation, UI/UX, edge cases, and tradeoffs.

```
I want to build [brief description]. Interview me in detail using the AskUserQuestion tool.

Ask about technical implementation, UI/UX, edge cases, concerns, and tradeoffs. Don't ask obvious questions, dig into the hard parts I might not have considered.

Keep interviewing until we've covered everything, then write a complete spec to SPEC.md.
```

### Common Failure Patterns

Recognizing these anti-patterns early saves time:

| Pattern | Symptom | Fix |
|---------|---------|-----|
| **Kitchen sink session** | Context full of irrelevant information from multiple unrelated tasks | `/clear` between unrelated tasks |
| **Over-correcting** | Same issue corrected multiple times, context polluted with failed approaches | After two failed corrections: `/clear` and write a better initial prompt incorporating what you learned |
| **Over-specified CLAUDE.md** | Claude ignores half of it because important rules get lost in the noise | Ruthlessly prune. If Claude already does something correctly without the instruction, delete it or convert it to a hook |
| **Trust-then-verify gap** | Plausible-looking implementation that doesn't handle edge cases | Always provide verification (tests, scripts, screenshots). If you can't verify it, don't ship it |
| **Infinite exploration** | "Investigate X" causes reading hundreds of files, filling context | Scope investigations narrowly or use subagents so the exploration doesn't consume your main context |

---

## Environment Configuration

### CLAUDE.md

CLAUDE.md is a special file that Claude reads at the start of every conversation. Include Bash commands, code style, and workflow rules. This gives Claude persistent context it can't infer from code alone.

**Effective Format**

Keep it short and human-readable. There's no required format, but conciseness matters because bloated CLAUDE.md files cause Claude to ignore your actual instructions.

Example:
```
# Code style
- Use ES modules (import/export) syntax, not CommonJS (require)
- Destructure imports when possible (eg. import { foo } from 'bar')

# Workflow
- Be sure to typecheck when you're done making a series of code changes
- Prefer running single tests, and not the whole test suite, for performance
```

**What to Include vs Exclude**

| Include | Exclude |
|---------|---------|
| Bash commands Claude can't guess | Anything Claude can figure out by reading code |
| Code style rules that differ from defaults | Standard language conventions Claude already knows |
| Testing instructions and preferred test runners | Detailed API documentation (link to docs instead) |
| Repository etiquette (branch naming, PR conventions) | Information that changes frequently |
| Architectural decisions specific to your project | Long explanations or tutorials |
| Developer environment quirks (required env vars) | File-by-file descriptions of the codebase |
| Common gotchas or non-obvious behaviors | Self-evident practices like "write clean code" |

**Import Syntax**

CLAUDE.md files can import additional files using `@path/to/import` syntax:

```
See @README.md for project overview and @package.json for available npm commands.

# Additional Instructions
- Git workflow: @docs/git-instructions.md
- Personal overrides: @~/.claude/my-project-instructions.md
```

**File Locations**

- **Home folder** (`~/.claude/CLAUDE.md`): Applies to all Claude sessions
- **Project root** (`./CLAUDE.md`): Check into git to share with your team, or name it `CLAUDE.local.md` and `.gitignore` it
- **Parent directories**: Useful for monorepos where both `root/CLAUDE.md` and `root/foo/CLAUDE.md` are pulled in automatically
- **Child directories**: Claude pulls in child CLAUDE.md files on demand when working with files in those directories

### Permissions

By default, Claude Code requests permission for actions that might modify your system. After many approvals, you're just clicking through without reviewing.

**Permission allowlists**: Permit specific tools you know are safe (like `npm run lint` or `git commit`)

**Sandboxing**: Enable OS-level isolation that restricts filesystem and network access, allowing Claude to work more freely within defined boundaries

**Skip permissions**: Use `--dangerously-skip-permissions` to bypass all permission checks for contained workflows like fixing lint errors or generating boilerplate

### Extensions

**CLI Tools**

CLI tools are the most context-efficient way to interact with external services. Claude is also effective at learning CLI tools it doesn't already know.

```
Use 'foo-cli-tool --help' to learn about foo tool, then use it to solve A, B, C.
```

**MCP Servers**

With MCP servers, you can ask Claude to implement features from issue trackers, query databases, analyze monitoring data, integrate designs from Figma, and automate workflows.

**Hooks**

Hooks run scripts automatically at specific points in Claude's workflow. Unlike CLAUDE.md instructions which are advisory, hooks are deterministic and guarantee the action happens.

```
/hooks
```

**Skills**

Skills extend Claude's knowledge with information specific to your project, team, or domain. Create a skill by adding a directory with a `SKILL.md` to `.claude/skills/`:

```
.claude/skills/api-conventions/SKILL.md

---
name: api-conventions
description: REST API design conventions for our services
---
# API Conventions
- Use kebab-case for URL paths
- Use camelCase for JSON properties
- Always include pagination for list endpoints
- Version APIs in the URL path (/v1/, /v2/)
```

**Subagents**

Subagents run in their own context with their own set of allowed tools. They're useful for tasks that read many files or need specialized focus without cluttering your main conversation.

```
.claude/agents/security-reviewer.md

---
name: security-reviewer
description: Reviews code for security vulnerabilities
tools: Read, Grep, Glob, Bash
model: opus
---
You are a senior security engineer. Review code for:
- Injection vulnerabilities (SQL, XSS, command injection)
- Authentication and authorization flaws
- Secrets or credentials in code
- Insecure data handling

Provide specific line references and suggested fixes.
```

**Plugins**

Plugins bundle skills, hooks, subagents, and MCP servers into a single installable unit from the community and Anthropic. If you work with a typed language, install a code intelligence plugin to give Claude precise symbol navigation and automatic error detection after edits.

---

## CLI Usage Patterns

### Headless Mode

With `claude -p "your prompt"`, you can run Claude headlessly, without an interactive session. Headless mode is how you integrate Claude into CI pipelines, pre-commit hooks, or any automated workflow.

```bash
# One-off queries
claude -p "Explain what this project does"

# Structured output for scripts
claude -p "List all API endpoints" --output-format json

# Streaming for real-time processing
claude -p "Analyze this log file" --output-format stream-json
```

### Unix-Style Usage

**Add Claude to Verification Process**

```json
// package.json
{
    "scripts": {
        "lint:claude": "claude -p 'you are a linter. please look at the changes vs. main and report any issues related to typos. report the filename and line number on one line, and a description of the issue on the second line. do not return any other text.'"
    }
}
```

**Pipe In, Pipe Out**

```bash
cat build-error.txt | claude -p "concisely explain the root cause of this build error" > output.txt
```

### Session Management

**Resume Conversations**

```bash
# Continue the most recent conversation in the current directory
claude --continue

# Select from recent conversations
claude --resume
```

From inside an active session, use `/resume` to switch to a different conversation.

**Reset Context**

```bash
/clear          # Reset context between unrelated tasks
/compact <instructions>    # Summarize with specific focus
```

**Rewind with Checkpoints**

Claude automatically checkpoints before changes. Run `/rewind` to open the checkpoint menu. You can restore conversation only (keep code changes), restore code only (keep conversation), or restore both.

### Plan Mode

**Start in Plan Mode**

```bash
claude --permission-mode plan
```

**Headless Plan Query**

```bash
claude --permission-mode plan -p "Analyze the authentication system and suggest improvements"
```

**Configure as Default**

```json
// .claude/settings.json
{
  "permissions": {
    "defaultMode": "plan"
  }
}
```

### Extended Thinking

**Set Token Budget**

Use the `MAX_THINKING_TOKENS` environment variable to cap the thinking budget:

```bash
export MAX_THINKING_TOKENS=10000
```

When thinking is enabled, Claude can use up to 31,999 tokens from your output budget for internal reasoning. When disabled, it uses 0 tokens for thinking.

### Parallel Sessions with Git Worktrees

Use git worktrees for complete code isolation between Claude Code instances when working on multiple tasks simultaneously.

---

## Developing Intuition

The patterns in this guide aren't set in stone. They're starting points that work well in general, but might not be optimal for every situation.

Sometimes you **should** let context accumulate because you're deep in one complex problem and the history is valuable. Sometimes you should skip planning and let Claude figure it out because the task is exploratory. Sometimes a vague prompt is exactly right because you want to see how Claude interprets the problem before constraining it.

Pay attention to what works. When Claude produces great output, notice what you did: the prompt structure, the context you provided, the mode you were in. When Claude struggles, ask why. Was the context too noisy? The prompt too vague? The task too big for one pass?

Over time, you'll develop intuition that no guide can capture. You'll know when to be specific and when to be open-ended, when to plan and when to explore, when to clear context and when to let it accumulate.
