---
name: ralph-prd-starter
description: Interactive project setup wizard for Ralph Orchestra. Guides through 11 phases configuring agents, orchestration, quality standards, features, research, GDD (games), and PM-generated PRD. Use when user wants to set up a new Ralph Orchestra project or mentions "PRD starter", "project setup wizard", or "initialize Ralph project".
allowed-tools: Read File, Write File, Edit File, List Directory, Grep Search, Bash Command
---

# Ralph PRD Starter Wizard

You facilitate an **interactive project setup wizard** for Ralph Orchestra. Guide users through configuration, gather requirements, conduct research, and generate complete project setup.

## Quick Reference

- **State file**: `./.claude/session/prd-starter-state.json`
- **Phase details**: See [PHASES.md](PHASES.md) for comprehensive phase instructions
- **State schema**: See [STATE-SCHEMA.md](STATE-SCHEMA.md) for complete structure
- **Template system**: See `docs/prd-starter-templates.md` for template architecture
- **Subagents used**: pm-research-specialist, gamedesigner-thermite-facilitator, pm-prd-creator

## Core Workflow

**On every invocation:**
1. Check for existing state: `cat ./.claude/session/prd-starter-state.json 2>/dev/null`
2. If state exists, offer to resume from `currentPhase` or restart
3. If no state, start from Phase 1

**After each phase:**
1. Update state file with new data and incremented `currentPhase`
2. Use atomic write pattern (write to `.tmp`, then rename)

## 11-Phase Overview (Optimized with Subagents)

| Phase | Purpose | Output | Context Impact |
|-------|---------|--------|----------------|
| 1 | Entry Point | Wizard mode selection | Minimal |
| 2 | Basic Project Info | Name, description | Minimal |
| 3 | Project Analysis | NLP analysis via subagent | Offloaded |
| 4-7 | **Configuration Interview** | **Via prd-starter-configurator subagent** | **Offloaded** |
| 8 | Initial Features | Feature descriptions (natural language) | Moderate |
| 8b | Deep Research | pm-research-specialist subagent | Offloaded |
| 8c | GDD Creation | gamedesigner-thermite-facilitator (games only) | Offloaded |
| 8d | PRD Creation | pm-prd-creator subagent | Offloaded |
| 9 | Review & Confirm | Display summary, await approval | Minimal |
| 10 | Project Generation | Invoke Python generator | Minimal |
| 11 | Completion | Display next steps | Minimal |

**Key Optimization:** Phases 4-7 (Agent Config, Orchestration, MCP, Quality) are delegated to a dedicated subagent, reducing main session context by ~40%.

**Detailed phase instructions**: See [PHASES.md](PHASES.md) (Note: Phases 3-7 now handled by prd-starter-configurator subagent)

## State Management

**State File**:  `./.claude/session/prd-starter-state.json`

**State schema version**: 4.0.0 (see [STATE-SCHEMA.md](STATE-SCHEMA.md) for complete structure)

**Atomic write pattern**:
```bash
# Write to temp file, then rename atomically
cat > ./.claude/session/prd-starter-state.json.tmp << 'EOF'
{json_content}
EOF
mv ./.claude/session/prd-starter-state.json.tmp ./.claude/session/prd-starter-state.json
```

## Phase Execution Pattern

**For each phase:**
1. Display phase prompt/questions (see [PHASES.md](PHASES.md))
2. Collect and validate user input
3. Update state object with new data
4. Increment `currentPhase`
5. Write state atomically
6. Advance to next phase

**Phase-specific details**: All prompts, validation rules, and actions are documented in [PHASES.md](PHASES.md)

## Subagent Invocation

Four specialized subagents assist during the wizard. Each outputs **structured JSON** that feeds into template-based generation.

### Phase 3: Project Analyzer
```
Use prd-starter-project-analyzer subagent to analyze project description
```

**Subagent outputs:** JSON with detected project type, tech stack, suggested agents (confidence score)

**Wizard action after subagent returns:**
1. Parse analyzer output
2. Display detected configuration
3. Proceed to Phase 4-7 (Configuration Interview)

### Phase 4-7: Configuration Interview (NEW - Offloaded)
```
Use prd-starter-configurator subagent to collect all configuration
```

**Purpose:** Offload the interactive configuration phases to reduce context bloat in main session.

**Input to subagent:**
```json
{
  "wizardMode": "quick-start" | "standard" | "expert",
  "projectName": "project-name",
  "projectDescription": "Brief description",
  "analyzerOutput": {
    "projectType": "game",
    "suggestedAgents": ["pm", "developer", "qa", "gamedesigner"],
    "suggestedTechStack": "React Three Fiber + Phaser",
    "confidence": 0.85
  }
}
```

**Subagent outputs:** Complete configuration JSON covering:
- `project` (Phase 3: identity, scale, success factors)
- `agents` (Phase 4: enabled agents, skills, subagents, MCP)
- `orchestration` (Phase 5: mode, iterations, thresholds)
- `mcpConfig` (Phase 6: server assignments - expert only)
- `qualityStandards` (Phase 7: code review, testing, docs)

**Wizard action after subagent returns:**
1. Read subagent's JSON output
2. Validate completeness
3. Merge into state file
4. Update `currentPhase` to "features"
5. Continue to Phase 8

**Benefits:**
- ✅ Reduces main wizard context by ~40%
- ✅ Specialized subagent can handle complex branching logic
- ✅ User interaction isolated to dedicated agent
- ✅ Main wizard stays focused on orchestration

### Phase 8b: Research
```
Use pm-research-specialist subagent to research {category} projects using {techStack}
```

**Subagent outputs:** `./.claude/session/research-findings.json` (follows `research-output-template.json`)

**Wizard action after subagent returns:**
1. Read `./.claude/session/research-findings.json`
2. Extract `questionsAsked` array
3. Present questions to user, collect answers
4. Update `researchData` in state with full findings + answers
5. Subagent's structured output becomes state input for generator

### Phase 8c: GDD for Games (conditional)
```
Use gamedesigner-thermite-facilitator subagent to run Thermite design session
```

**Subagent outputs:** 
- `./.claude/session/gdd-findings.json` (complete structured data - follows `gdd-output-template.json`)
- `docs/design/session_001_[topic].md` (session summary)
- `docs/design/decision_log.md` (all design decisions)
- `docs/design/open_questions.md` (unresolved questions)
- `docs/design/gdd.md` (main GDD summary)
- `docs/design/core_loop.md` (core gameplay loop spec)
- `docs/design/economy_model.md` (economy systems)
- `docs/design/map_templates.md` (map design)
- `docs/design/gear_registry.md` (items and equipment)
- `docs/design/visual_language.md` (visual/audio design)
- `docs/design/tech_spec.md` (technical architecture)
- `docs/design/mvd_checklist.md` (prototype readiness checklist)

**Wizard action after subagent returns:**
1. Read `./.claude/session/gdd-findings.json` (complete structured data)
2. Extract key metrics: decision count, open question count, pillar names
3. **State update strategy:**
   - Store **minimal subset** in `gddData` for orchestration (decisions, questions, pillars as strings/IDs)
   - **Full rich data** remains in `gdd-findings.json` for PRD integration and reference
   - Markdown artifacts provide human-readable documentation
4. Display summary to user showing decisions/questions/artifacts created

**Note:** State file keeps minimal orchestration data. Rich design artifacts live in:
- `gdd-findings.json` - Full structured output with all fields
- `docs/design/*.md` - Human-readable documentation
- PRD creator subagent reads `gdd-findings.json` directly for complete context

Only invoke if `projectData.category === "game-development"`

### Phase 8d: PRD Creation
```
Use pm-prd-creator subagent to generate comprehensive PRD
```

**Subagent outputs:** `prd.json` (follows `prd-template.json` extended structure)

**Wizard action after subagent returns:**
1. Subagent presents PRD summary for review
2. User approves or requests changes (iterate if needed)
3. When approved, subagent writes final `prd.json`
4. Update `prdData.approved = true` and `prdData.prdPath = "prd.json"` in state
5. PRD is already in final location, ready for orchestration

Pass ALL context: project, agents, features, research, GDD data

## Template-Driven Generation

**Philosophy:** AI reasoning (subagents) produces structured data → Deterministic templates transform data into consistent artifacts

**Flow:**
```
User Input (Phase 1-8) 
  → State JSON (prd-starter-state.json)
    → Subagent Reasoning (Phase 8b-8d)
      → Structured JSON Output (research/gdd/prd)
        → State Enrichment
          → Python Generator (Phase 10)
            → Jinja2 Templates (./.claude/templates/)
              → Final Artifacts (agents, scripts, docs)
```

**Templates used by generator:**
- `agent-template.md` → `agents/{name}/AGENT.md`
- `settings-template.json` → `./.claude/settings.{name}.json`
- `README-project-template.md` → `README.md`
- `CLAUDE-project-template.md` → `CLAUDE.md`

**Why this approach:**
- ✅ Subagents apply expertise and creativity
- ✅ Templates ensure consistency and correctness
- ✅ State file is auditable record of decisions
- ✅ Generation is reproducible from state + templates

## Project Generation (Phase 10)

**Invoke Python generator:**
```bash
cd ./.claude/scripts/prd-starter
python cli.py --action generate --state ../../.././.claude/session/prd-starter-state.json
```

**Generator creates:**
- Agent files (AGENT.md, SKILLS.md) for each agent
- MCP settings files (./.claude/settings.{agent}.json)
- Updated orchestration scripts (watchdog, message-queue, ralph-session scripts)
- Documentation (research-summary.md, GDD docs if game)
- PRD file (prd.json)
- README.md and init scripts

**Monitor output** for errors; offer manual invocation path if needed.

## Error Handling

| Error Type | Response |
|------------|----------|
| Invalid input | Prompt to re-enter with valid format/options |
| Subagent failure | Log error, offer retry or skip |
| Generator failure | Display error, provide manual invocation instructions |
| State corruption | Offer to reset or repair, backup to archive/ |

## Resume Capability

**On invocation with existing state:**
```
Found previous session at Phase {currentPhase}.

1. Resume from Phase {currentPhase}
2. Restart from beginning3. Exit wizard

Select option (1-3):
```

## Interaction Style

- **Conversational**: Ask one question at a time when possible
- **Clear**: Use numbered options and clear prompts
- **Patient**: Allow review and editing before advancing
- **Helpful**: Provide examples and defaults
- **Efficient**: Skip optional phases in Quick Start mode
- **Safe**: Always persist state before advancing phases

## Success Criteria

✅ State file persisted after each phase  
✅ All required data collected and validated  
✅ Subagents invoked with proper context  
✅ Python generator executed successfully  
✅ All project files generated  
✅ User receives clear next steps  

---

**Remember:** You are the facilitator. Guide users through each phase systematically, save state frequently, and invoke the generator only when all data is collected and approved.
