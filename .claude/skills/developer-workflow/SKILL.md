---
name: developer-workflow
description: Complete Developer workflow orchestration - task research sequence, implementation flow, validation gates, PRD synchronization, exit conditions.
---

# Developer Workflow

> "This skill orchestrates the development workflow sequence. For detailed implementation guidance."

## Core Responsibilities

- **Load the proper skills and tools** - Always ensure you have the right skills loaded for each task. Run tasks and subagents in parallel when possible to optimize time.
- **Task Research** - Research and plan implementation before coding. Read PRD, ask questions, research solutions, and create a clear implementation plan.
- **Implementation** - Write code to implement assigned tasks. Follow best practices, maintain code quality, and ensure functionality.
- **Validation** - Run validation steps and fix issues until passing. Use `qa-validation-workflow` skill for guidance.
  - **CRITICAL:** NEVER CREATE FAKE OR TRIVIAL TESTS. If a test cannot be created with meaningful assertions based on the specs/gdd requirements, DO NOT CREATE A TEST. Instead, report the issue to PM and document the gap in test coverage in the task comments and close the task as completed with observations.
- **PRD Synchronization** - Update PRD with implementation details, blockers, and observations. Keep PM informed of progress and issues.
- **Exit Conditions** - Only exit when task is fully implemented, validated, and PRD is updated. Never exit prematurely or leave tasks in an incomplete state.

## Standard Message Pipeline

- Read message input in this order: CLI message argument → `pending-messages-developer.json` → inbox diagnostics
- Never delete queue files (`messages/*`) or pending transaction files (`pending-messages-*.json`)
- Watchdog owns delivery and cleanup lifecycle
- Signal lifecycle using `status_update`:
  - `working` when execution starts
  - `awaiting_pm` / `awaiting_gd` when blocked
  - `ready` / `waiting` / `idle` when available for next delivery

## Agent Startup Protocol 

On each Developer agent spawn:

1. **Read Task Assignment** 
   - Check CLI message argument (`$arguments.message` for Claude CLI, or initial prompt for OpenCode CLI)
   - If CLI payload is empty, check `./.claude/session/pending-messages-developer.json`
   - If both are missing, inspect `./.claude/session/messages/developer/*.json` for diagnostics only
2. **Read task state file** read and understand current task details and status
3. **Research task requirements** Understand the requirements, read the specifications, use MCP tools (WebSearch, Fetch) to clarify implementation details, best practices, and potential blockers
4. **Use your skills, tools, and subagents** After understand the task requirements, review the available skills, subagents and tools, and activate the ones to use for the implementation.
5. **Create a implementation plan** document your approach in an implementation plan. Create steps and a checklist, update the task comments, and update PRD if needed
6. **Update task state** to "in_progress" in task state file (atomic write)
7. **Process and implement the task** following your plan and best practices, using the appropriate skills, subagents, and tools as needed
8. **Run validation** using `qa-validation-workflow` skill and fix any issues until passing
9. **Run code base clean up subagent** After any non-bug task completion, is mandatory to run the `code-refactor` subagent parallel task with the implemented context, to ensure code quality and maintainability
10. **Update PRD and commit changes** with implementation details, blockers, and observations (atomic write). Commit the changes following the default commit message pattern.
11. **Notify the next agent** wake up the next agent that needs to act after your actions via message system
12. **Exit** Send `status_update` (`ready`, `waiting`, or `idle`) to watchdog and wake up the next agent before exiting

**IF BLOCKED**
- Update state: `state.status = "awaiting_pm"`, `state.lastSeen = "{ISO_TIMESTAMP}"`
- Document blocker in task prd.json
- Send message to PM with details
- Send `status_update` to watchdog with `status: "awaiting_pm"`
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
