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

## Agent Startup Protocol 

On each Tech Artist agent spawn:

1. **Read --message argument** (task assignment from watchdog)
2. **Read task state file** read and understand current task details and status
3. **Research task requirements** Understand the requirements, read the specifications, use MCP tools (WebSearch, Fetch) to clarify implementation details, best practices, and potential blockers. Use Vision MCP for visual research and references. Create visual mood boards, reference collections, and implementation plans to clarify the visual direction and technical approach before starting implementation. For UI, use CSS and HTML to generate prototypes and mockups to validate the visual design and interactions before coding.

**PRE-REQUISITE: You should already have loaded the `shared-worktree` skill and be in the correct worktree directory before starting this step!**

4. **Create a implementation plan** document your approach in an implementation plan. Create steps and a checklist, update the task comments, and update PRD if needed
5. **Update task state** to "in_progress" in task state file (atomic write)
6. **Process and implement the task** following your plan and best practices, using the appropriate skills, subagents, and tools as needed
8. **Run code validation** using `qa-validation-workflow` skill and fix any issues until passing
9. **Run visual validation** using `qa-visual-testing` skill with Vision MCP for image analysis, and fix any issues until passing
10. **Update PRD and commit changes** with implementation details, blockers, and observations (atomic write). Commit the changes following the default commit message pattern.
11. **Notify the next agent** wake up the next agent that needs to act after your actions via message system
12. **Exit** Update your status to "ready" to watchdog and wake up the next agent before exiting, so watchdog can track availability for next task assignment

**IF BLOCKED**
- Update state: `state.status = "awaiting_pm"`, `state.lastSeen = "{ISO_TIMESTAMP}"`
- Document blocker in task prd.json
- Send message to PM/Game Designer with details
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