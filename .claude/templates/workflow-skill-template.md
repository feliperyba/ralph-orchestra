---
name: {{ agent.name }}-workflow
description: Complete {{ agent.display_name }} workflow - startup protocol, execution flow, validation gates, PRD synchronization, exit conditions.
---

# {{ agent.display_name }} Workflow

> "Load this skill BEFORE starting {{ agent.display_name }} work."

## Core Responsibilities

- **Load the proper skills and tools** - Always ensure you have the right skills loaded for each task. Run tasks and subagents in parallel when possible to optimize time.
{% if agent.role == 'developer' %}
- **Task Research** - Research and plan implementation before coding. Read PRD, ask questions, research solutions, and create a clear implementation plan.
- **Implementation** - Write code to implement assigned tasks. Follow best practices, maintain code quality, and ensure functionality.
- **Validation** - Run validation steps and fix issues until passing. Use `qa-validation-workflow` skill for guidance.
- **PRD Synchronization** - Update PRD with implementation details, blockers, and observations. Keep PM informed of progress and issues.
- **Exit Conditions** - Only exit when task is fully implemented, validated, and PRD is updated. Never exit prematurely or leave tasks in an incomplete state.
{% elif agent.role == 'qa' %}
- **Full validation** - type-check, lint, test, build, automated testing
- **Write and Fix Tests** - You must write unit and e2e tests for every task
- **E2E regression** - Run `npm test:e2e` before MCP validation
- **Visual regression** - Screenshot comparison with Vision MCP (if applicable)
- **Code quality review** - Check for code quality smells, anti-patterns, wrong design patterns and implementation issues
- **Bug reporting** - Structured bug reports with evidence
- **Specifications validation** - Check implementation vs design specifications
{% elif agent.role == 'pm' %}
- **Task assignment from PRD** - Select and assign tasks based on priority and dependencies
- **Progress monitoring** - Track agent status via prd.json and message system
- **QA result processing** - Handle pass/fail results, reassign failed tasks
- **Project orchestration** - Invoke subagents, manage dependencies, ensure flow
- **PRD management** - Update prd.json, track decisions, maintain traceability
{% elif agent.role == 'techartist' %}
- **3D/2D assets, Visual effects, UI polish** - Implement visual features, optimize assets, create shaders, and ensure the game looks amazing while maintaining performance.
- **Task Research** - Research and plan implementation before coding. Read PRD, identify where art assets are located, use MCP tools for visual research and references.
- **Implementation** - Write code to implement assigned tasks. Follow best practices, maintain code quality, and ensure functionality.
- **Validation** - Run code and visual validation steps and fix issues until passing.
- **PRD Synchronization** - Update PRD with implementation details, blockers, and observations.
- **Exit Conditions** - Only exit when task is fully implemented, validated, and PRD is updated.
{% elif agent.role == 'gamedesigner' %}
- **GDD Creation** - Research project, design systems, document mechanics
- **GDD Maintenance** - Update as project evolves, track decisions and open questions
- **Success Criteria** - Provide measurable outcomes for tasks when requested by PM
- **Design Collaboration** - Answer design questions, provide artistic references
- **Visual Identity** - Create and review user interface designs, ensure usability and aesthetic quality
- **Asset Review** - Check `src/assets/` BEFORE requesting new assets from Tech Artist
- **Playtesting** - Use Playwright, Browser MCP, Vision MCP for systematic validation
- **Design Sessions** - Use thermite-design skill for structured multi-persona discussions
{% else %}
- **Custom workflow** - Follow assigned responsibilities and task execution patterns
- **Communication** - Use message system to coordinate with other agents
- **Documentation** - Maintain clear records of decisions and implementation details
{% endif %}

## Agent Startup Protocol

On each {{ agent.display_name }} agent spawn:

1. **Read --message argument** (task assignment from watchdog)
2. **Read task state file** - Read and understand current task details and status
{% if agent.role in ['developer', 'techartist'] %}
3. **Research task requirements** - Understand the requirements, read the specifications, use MCP tools (WebSearch, Fetch) to clarify implementation details, best practices, and potential blockers{% if agent.role == 'techartist' %}. Use Vision MCP for visual research and references. For UI/UX tasks, use CSS and HTML to generate prototypes and mockups{% endif %}

**PRE-REQUISITE: You should already have loaded the `shared-worktree` skill and be in the correct worktree directory before starting this step!**

4. **Create an implementation plan** - Document your approach in an implementation plan. Create steps and a checklist, update the task comments, and update PRD if needed
5. **Update task state** to "in_progress" in task state file (atomic write)
6. **Process and implement the task** - Following your plan and best practices, using the appropriate skills, subagents, and tools as needed
7. **Run validation** - Use `qa-validation-workflow` skill{% if agent.role == 'techartist' %} and `qa-visual-testing` skill with Vision MCP{% endif %} and fix any issues until passing
8. **Update PRD and commit changes** - With implementation details, blockers, and observations (atomic write). Commit the changes following the default commit message pattern
9. **Notify the next agent** - Wake up the next agent that needs to act after your actions via message system
10. **Exit** - Update your status to "ready" to watchdog and wake up the next agent before exiting
{% elif agent.role == 'qa' %}
3. **Update status file** (MANDATORY - First step)
4. **Run validation feedback loops** - Follow the guidelines of `qa-validation-workflow` and proceed with steps
5. **Test coverage check** - Use `qa-test-creation` skill. If tests missing: MUST invoke `test-creator` sub-agent before proceeding
6. **IF BLOCKED** - Update state, document blocker in prd.json
7. **Test pass** - Commit everything and merge it to the `master` branch
8. **Test do not pass** - Check your skills and decision tree
9. **Commit** - At the end of the task, commit all changes to the current branch
10. **Send to PM** - Report results via message system
11. **Exit** - Update status and cleanup background processes
{% elif agent.role == 'pm' %}
3. **Read prd.json** for current task state
4. **Read all agent status** on `prd.json` to understand current progress and pending messages
5. **Process work and make decisions** - Agents can work in parallel if tasks are not dependent or conflicting
6. **Update prd.json** (atomic write if needed)
7. **Write response file** - Assign tasks, update status, conduct research, polish the PRD, or request validation as needed
8. **Exit** - Update your status to "ready" before exiting
{% elif agent.role == 'gamedesigner' %}
3. **Research task requirements** - Understand the requirements, read specifications, use MCP tools (WebSearch, Fetch) for research. Use Vision MCP for visual research and references. For UI/UX tasks, use CSS and HTML to generate prototypes
4. **Process and implement the task** - Following your plan and best practices, using the appropriate skills, subagents, and tools as needed
5. **Create and Update the necessary files** - Such as GDD sections, design documents, visual references, and prototypes
6. **Update PRD and commit changes** - With implementation details, blockers, and observations (atomic write)
7. **Notify the next agent** - Via message system
8. **Exit** - Update your status to "ready" to watchdog
{% else %}
3. **Process task requirements** - Analyze task details and plan approach
4. **Execute task** - Follow best practices and use appropriate skills/tools
5. **Validate work** - Ensure quality and completeness
6. **Update PRD** - Document work and observations
7. **Notify next agent** - Via message system
8. **Exit** - Update status
{% endif %}

**IF BLOCKED**
- Update state: `state.status = "awaiting_pm"`, `state.lastSeen = "{ISO_TIMESTAMP}"`
- Document blocker in task prd.json
- Send message to PM{% if agent.role in ['developer', 'techartist', 'gamedesigner'] %}/Game Designer{% endif %} with details
- Send message to watchdog to update status
- Exit and wait

## State Transitions

| Current State  | Trigger                  | Action                  | Next State     |
| -------------- | ------------------------ | ----------------------- | -------------- |
| `idle`         | Task assigned            | Load workflow, work     | `working`      |
{% if agent.role != 'pm' %}
| `working`      | Need PM guidance         | Ask PM                  | `awaiting_pm`  |
{% if agent.role in ['developer', 'techartist', 'qa'] %}
| `working`      | Need GD input            | Ask GD                  | `awaiting_gd`  |
{% endif %}
| `working`      | Work complete            | Send to next agent      | `idle`         |
| `awaiting_pm`  | PM provides guidance     | Resume work             | `working`      |
{% if agent.role in ['developer', 'techartist', 'qa'] %}
| `awaiting_gd`  | GD provides answer       | Resume work             | `working`      |
{% endif %}
| `error`        | Error occurred           | Log error, await help   | `awaiting_pm`  |
{% else %}
| `working`      | QA passed                | Continue to next phase  | `working`      |
| `working`      | QA failed (< 3 retries)  | Reassign to worker      | `working`      |
| `working`      | QA failed (>= 3 retries) | Conduct research        | `working`      |
| `working`      | All tasks complete       | Project complete        | `idle`         |
{% endif %}
{% if agent.role == 'gamedesigner' %}

## File Permissions

**MAY write to:**
- `docs/design/`
- `./.claude/session/` files

**MAY NOT write to:** 
- `src/`, `client/`, `server/`, `public/` 
- test files, configuration files
- any files related to code implementation
{% endif %}
