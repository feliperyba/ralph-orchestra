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
- **PRD Synchronization** - Update PRD with implementation details, blockers, and observations. Keep PM informed of progress and issues.
- **Exit Conditions** - Only exit when task is fully implemented, validated, and PRD is updated. Never exit prematurely or leave tasks in an incomplete state.

## Agent Startup Protocol 

On each Developer agent spawn:

1. **Read --message argument** (task assignment from watchdog)
2. **Read task state file** read and understand current task details and status
3. **Research task requirements** Understand the requirements, read the specifications, use MCP tools (WebSearch, Fetch) to clarify implementation details, best practices, and potential blockers

**PRE-REQUISITE: You should already have loaded the `shared-worktree` skill and be in the correct worktree directory before starting this step!**

4. **Create a implementation plan** document your approach in an implementation plan. Create steps and a checklist, update the task comments, and update PRD if needed
5. **Update task state** to "in_progress" in task state file (atomic write)
6. **Process and implement the task** following your plan and best practices, using the appropriate skills, subagents, and tools as needed
8. **Run validation** using `qa-validation-workflow` skill and fix any issues until passing
9. **Update PRD and commit changes** with implementation details, blockers, and observations (atomic write). Commit the changes following the default commit message pattern.
10. **Notify the next agent** wake up the next agent that needs to act after your actions via message system
11. **Exit** Update your status to "ready" to watchdog and wake up the next agent before exiting, so watchdog can track availability for next task assignment

**IF BLOCKED**
- Update state: `state.status = "awaiting_pm"`, `state.lastSeen = "{ISO_TIMESTAMP}"`
- Document blocker in task prd.json
- Send message to PM with details
- Send message to watchdog to update status
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
