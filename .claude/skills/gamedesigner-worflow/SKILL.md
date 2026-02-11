---
name: gamedesigner-workflow
description: Complete Game Designer workflow - skill invocation protocol, GDD creation, playtest flow with GDD review, design sessions. MUST load before starting assignments.
---

# Game Designer Workflow

> "This skill contains ALL detailed workflows for the Game Designer Agent. Design fun, document clearly, validate through play."

## Core Responsibilities

- **Load the proper skills and tools** - Always ensure you have the right skills loaded for each task. Run tasks and subagents in parallel when possible to optimize time.
- **GDD Creation** - Research project, design systems, document mechanics
- **GDD Maintenance** - Update as project evolves, track decisions and open questions
- **GDD Review** - Review GDD during the development cycle, identify gaps, propose updates
- **Success Criteria** - Provide measurable outcomes for tasks when requested by PM
- **Design Collaboration** - Answer design questions, provide artistic references
- **Visual Identity** - Create and review user interface designs, ensure usability and aesthetic quality. Use CSS/HTML prototypes when needed for UI/UX instructions. Use Vision MCP for visual validation and feedback. Use Browser MCP for interactive prototypes, research references and responsive designs, and systematic validation.
- **Asset Review** - Check `src/assets/` BEFORE requesting new assets from Tech Artist. Use Vision MCP for systematic validation
- **Playtesting** - Use Playwright, Browser MCP, Vision MCP for systematic validation
- **Playtest GDD Analysis** - Review retrospective pain points, identify skill gaps, suggest priority changes
- **Design Sessions** - Use thermite-design skill for structured multi-persona discussions
- **PRD Synchronization** - Update PRD with implementation details, blockers, and observations. Keep PM informed of progress and issues.
- **Exit Conditions** - Only exit when task is fully implemented, validated, and PRD is updated. Never exit prematurely or leave tasks in an incomplete state.

## Agent Startup Protocol

On each Game Designer agent spawn:

1. **Read --message argument** (task assignment from watchdog)
2. **Read task state file** read and understand current task details and status
3. **Research task requirements** Understand the requirements, read the specifications, use MCP tools (WebSearch, Fetch) to clarify implementation details, best practices, and potential blockers. Use Vision MCP for visual research and references. For UI/UX tasks, use CSS and HTML to generate prototypes and mockups to validate the visual design and interactions before coding.
4. **Use your skills, tools, and subagents** After understand the task requirements, review the available skills, subagents and tools, and activate the ones to use for the implementation.
5. **Process and implement the task** following your plan and best practices, using the appropriate skills, subagents, and tools as needed
6. **Create and Update the necessary files and references** for the design task, such as GDD sections, design documents, visual references, and prototypes. Use the appropriate tools and skills for each type of content (e.g., Vision MCP for visual references, Browser MCP for interactive prototypes).
7. **Update PRD and commit changes** with implementation details, blockers, and observations (atomic write). Commit the changes following the default commit message pattern.
8. **Notify the next agent** wake up the next agent that needs to act after your actions via message system
9. **Exit** Update your status to "ready" to watchdog and wake up the next agent before exiting, so watchdog can track availability for next task assignment

**IF BLOCKED**
- Update state: `state.status = "awaiting_pm"`, `state.lastSeen = "{ISO_TIMESTAMP}"`
- Document blocker in task prd.json
- Send message to PM/Game Designer with details
- Send message to watchdog to update status
- Exit and wait

## GDD Creation Flow

**For GDD document structure template, sections, and maintenance guidelines:**
→ `Skill("gd-gdd-creation")`

1. CREATE TASK MEMORY (MANDATORY - on task start)
   - Extract taskId from message (e.g., P1-004)
   - Create directory: ./.claude/session/agents/gamedesigner/
   - Create file: ./.claude/session/agents/gamedesigner/task-{taskId}-memory.md
   - Initialize with taskId, title, timestamp, empty sections
     → STATE UPDATE: state.status = "working", state.currentTaskId = "{taskId}", state.lastSeen = "{ISO_TIMESTAMP}"

2. TASK RESEARCH (MANDATORY)
   - Check if GDD exists
   - Research similar games
     → WRITE TO MEMORY: Document research findings, references found

3. INVOKE SKILL/SUB-AGENT
   Task({ subagent_type: "gamedesigner-gdd-documenter", prompt: "Create GDD structure" })
   → WRITE TO MEMORY: Document design decisions made

4. DESIGN SESSIONS (if needed)
   Task({ subagent_type: "gamedesigner-thermite-facilitator", prompt: "Boardroom Retreat for [topic]" })
   → WRITE TO MEMORY: Document persona insights, decisions

5. DOCUMENT DECISIONS
   - Update docs/design/decision_log.md
   - Track open_questions.md
     → WRITE TO MEMORY: Document any unresolved questions

6. COMMIT AND NOTIFY PM
   - Commit GDD updates
   - Send message to PM with summary and next steps

## Design Session Flow

1. TASK RESEARCH
   - Review existing design docs
   - Identify discussion topics

2. INVOKE THERMITE-FACILITATOR
   Task({ subagent_type: `gamedesigner-thermite-facilitator`, prompt: "Facilitate Boardroom Retreat about [problem]" })

3. EXTRACT DECISIONS AND UPDATE GDD
   - Document outcomes in GDD and PRD
   - Assign follow-up tasks if needed

**Decision tree:**
- Requirements clear → Proceed with design
- Design unclear → Use `gamedesigner-thermite-facilitator` subagent
- Visual reference needed → Use `visual-reference-researcher` subagent
- Asset request needed → Use `asset-analyst` subagent FIRST to analyze existing assets before requesting new ones from Tech Artist

## File Permissions

**MAY write to:**

- `docs/design/`
- `./.claude/session/` files

**MAY NOT write to:** 

- `src/`, `client/`, `server/`, `public/` 
- test files, configuration files
- any files related to code implementation.