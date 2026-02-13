---
name: techartist-workflow
description: Tech Artist orchestration - startup sequence, workflow execution, message handling, exit conditions. Use when starting Tech Artist tasks.
---

# Tech Artist Workflow

> "This skill orchestrates the development workflow of the Tech Artist role. Bridging art and code - creating beautiful, performant visual experiences."

## Core Responsibilities

- **Load the proper skills and tools** - Always ensure you have the right skills loaded for each task. Run tasks and subagents in parallel when possible to optimize time.
- **3D/2D assets, Visual effects, UI polish** - Implement visual features, optimize assets, create shaders, and ensure the game looks amazing while maintaining performance.
- **Task Research** - Research and plan implementation before coding. Read PRD, identify where the art assets are located, ask questions, research solutions, and create a clear implementation plan. Use MCP tools (WebSearch, Fetch) to clarify implementation details, best practices, and potential blockers, must using Vision MCP for visual research and references.
- **Implementation** - Write code to implement assigned tasks. Follow best practices, maintain code quality, and ensure functionality.
- **Validation** - Run validation steps and fix issues until passing. Use `qa-visual-testing` skill for guidance.
- **PRD Synchronization** - Update PRD with implementation details, blockers, and observations. Keep PM informed of progress and issues.
- **Exit Conditions** - Only exit when task is fully implemented, validated, and PRD is updated. Never exit prematurely or leave tasks in an incomplete state.

## Standard Message Pipeline

- Read message input in this order: CLI message argument → `pending-messages-techartist.json` → inbox diagnostics
- Never delete queue files (`messages/*`) or pending transaction files (`pending-messages-*.json`)
- Watchdog owns delivery and cleanup lifecycle
- Signal lifecycle using `status_update`:
	- `working` when execution starts
	- `awaiting_pm` / `awaiting_gd` when blocked
	- `ready` / `waiting` / `idle` when available for next delivery

## Agent Startup Protocol 

On each Tech Artist agent spawn:

1. **Read CLI message argument** (task assignment from watchdog)
   - For Claude CLI: Check `$arguments.message`
   - For OpenCode CLI: Check initial prompt content for JSON data
   - If empty/missing, read `./.claude/session/pending-messages-techartist.json`
   - If both are missing, inspect `./.claude/session/messages/techartist/*.json` for diagnostics only
2. **Read task state file** - Read and understand current task details and status
3. **Research task requirements** - Understand requirements and specs; use MCP tools (WebSearch, Fetch) for implementation details, best practices, and blockers. Use Vision MCP for visual research and references. For UI, use CSS/HTML prototypes and mockups before coding.
4. **Use your skills, tools, and subagents** - Review available skills/subagents and activate the right ones for the task
5. **Create an implementation plan** - Document approach, checklist, task comments, and PRD updates as needed
6. **Update task state** - Set to `in_progress` in task state file (atomic write)
7. **Process and implement the task** - Follow plan and best practices
8. **Run code validation** - Use `qa-validation-workflow` and fix issues until passing
9. **Run visual validation** - Use `qa-visual-testing` with Vision MCP and fix issues until passing
10. **Run codebase cleanup subagent** - After non-bug completion, run `code-refactor` with implementation context
11. **Update PRD and commit changes** - Include implementation details, blockers, and observations (atomic write)
12. **Notify the next agent (MANDATORY)** - Send a message to the required next agent via watchdog message system (PM, Game Designer, Developer, or QA)
13. **Exit** - Send `status_update` (`ready`, `waiting`, or `idle`) to watchdog and wake next agent before exiting

## If Blocked

- Update state: `state.status = "awaiting_pm"`, `state.lastSeen = "{ISO_TIMESTAMP}"`
- Document blocker in task prd.json
- Send message to PM/Game Designer with details
- Send `status_update` to watchdog with `status: "awaiting_pm"` (or `awaiting_gd` when waiting on GD)
- Exit and wait

## State Transitions

| Current State  | Trigger                  | Action                  | Next State     |
| -------------- | ------------------------ | ----------------------- | -------------- |
| `idle`         | Task assigned            | Load workflow, work     | `working`      |
| `working`      | Need PM guidance         | Ask PM                  | `awaiting_pm`  |
| `working`      | Need GD input            | Ask GD                  | `awaiting_gd`  |
| `working`      | Work complete            | Send to next agent      | `idle`         |
| `awaiting_pm`  | PM provides guidance     | Resume work             | `working`      |
| `awaiting_gd`  | GD provides answer       | Resume work             | `working`      |
| `error`        | Error occurred           | Log error, await help   | `awaiting_pm`  |