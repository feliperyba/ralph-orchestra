# Sub-Agent Integration Protocol Template

## Overview

This document defines the standard protocol for integrating sub-agents within Ralph Orchestra. It ensures consistent data flow, state management, and error handling between parent agents and sub-agents.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Parent Agent                                │
│                  (e.g., prd-starter)                            │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              │ 1. Load state
                              │ 2. Prepare prompt
                              │ 3. Invoke Task tool
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Sub-Agent                                   │
│              (e.g., pm-research-specialist)                     │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐│
│  │   Read State    │───▶│  Process Data   │───▶│ Write State ││
│  │  (if needed)    │    │  (expertise)   │    │  (if allowed)││
│  └─────────────────┘    └─────────────────┘    └─────────────┘│
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              │ 4. Return structured output
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Parent Agent                                │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐│
│  │ Receive Output  │───▶│ Update State    │───▶│   Continue  ││
│  │                 │    │                 │    │   Next Phase││
│  └─────────────────┘    └─────────────────┘    └─────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Phase Flow

### PRD Starter Phase Sequence

| Phase | Name | Sub-Agent | Output State Field |
|-------|------|-----------|-------------------|
| 8 | Initial Features | None | `features` |
| 8b | Deep Research | pm-research-specialist | `researchData` |
| 8b-user | User Questions | None (parent agent) | `researchData.questionsAnswered` |
| 8c | GDD Creation (games only) | gamedesigner-thermite-facilitator | `gddData` |
| 8d | PRD Creation | pm-prd-creator | `prd.json` file |
| 9 | Final Review | None | User approval |

## Task Invocation Pattern

### Parent Agent: Invoking Sub-Agent

```markdown
## Phase X: {Phase Name}

{Context about what phase accomplishes}

**Action:** Use Task tool to invoke {sub-agent-name}

**Prompt template:**
```
{Task description with specific instructions}

Input Data:
- Project: {project.name}
- Description: {project.description}
- Category: {project.category}
- Tech Stack: {project.techStack}
- Features: {features_list}
- Previous Data: {previous_phase_output}

Your task:
1. {Specific step 1}
2. {Specific step 2}
3. {Specific step 3}

Return structured output matching your output template.
```

**After sub-agent completes:**
1. Receive and parse output
2. Update state file with phase data
3. Present summary to user
4. Ask for continuation/modification
```

### Sub-Agent: Response Format

Sub-agents should respond with:

```markdown
## {Sub-Agent Name} Results

### Summary
{Brief overview of what was accomplished}

### Phase Data
{Structured data matching the output template}

### Files Created/Modified
- [ ] `file1.ext` - Description
- [ ] `file2.ext` - Description

### Next Steps
{Recommendation for what should happen next}

### Output JSON
```json
{
  "phaseData": { ... },
  "nextStep": "next_phase_name",
  "userPrompt": "What to show user"
}
```
```

## State File Management

### State File Location

```
.claude/session/prd-starter-state.json
```

### State Update Protocol

**Parent Agent Responsibilities:**
1. Read existing state before invoking sub-agent
2. Pass relevant state fields to sub-agent in prompt
3. Receive output from sub-agent
4. Update state with new phase data
5. Write updated state back to file
6. Update `currentPhase` and `lastModified` fields

**Sub-Agent Responsibilities:**
1. Read state file if needed for context (if Read tool available)
2. Process data using sub-agent expertise
3. Return structured output (does NOT write state if read-only)
4. If Write tool available, may update designated state fields

### State Field Ownership

| State Field | Owner | Writer | Reader |
|-------------|-------|--------|--------|
| `currentPhase` | Parent Agent | Parent Agent | All |
| `project` | Parent Agent | Parent Agent | All |
| `features` | Parent Agent | Parent Agent | All |
| `researchData` | pm-research-specialist | Sub-Agent | Parent, pm-prd-creator |
| `gddData` | thermite-facilitator | Sub-Agent | Parent, pm-prd-creator |
| `prdSpecification` | pm-prd-creator | Sub-Agent | Parent |
| `agents` | Parent Agent | Parent Agent | pm-prd-creator |
| `orchestration` | Parent Agent | Parent Agent | pm-prd-creator |

## Error Handling

### Sub-Agent Error Response

If a sub-agent encounters an error:

```markdown
## Error: {Error Type}

**Phase:** {current_phase}
**Sub-Agent:** {sub_agent_name}
**Error:** {error_description}

**Recovery Options:**
1. Retry with modified prompt
2. Skip this phase (if non-critical)
3. Request user intervention

**State:** No state changes were made.
```

### Parent Agent Error Handling

```markdown
If sub-agent returns error:
1. Log error to state file under `generationResults.errors`
2. Display error to user
3. Ask: Retry / Skip / Modify / Abort
4. Update `currentPhase` to indicate recovery point
```

## Data Passing

### Via Prompt (Current Pattern)

```javascript
// Parent agent constructs prompt
const prompt = `
Research this project:
Project: ${state.project.name}
Description: ${state.project.description}
Features: ${state.features.join(', ')}

Your task: Research similar projects and return structured data.
`;

// Invoke sub-agent
Task("pm-research-specialist", { prompt });
```

### Via State File (Alternative Pattern)

```javascript
// Parent agent writes input state
state.inputData = { project, features };
writeState(state);

// Sub-agent reads state file
const state = readState();
const input = state.inputData;

// Sub-agent processes and writes output
state.researchData = process(input);
writeState(state);
```

### Via Temporary File (For Large Data)

```javascript
// Parent agent writes temp file
writeFile('.claude/session/input.json', largeData);

// Sub-agent reads temp file
const input = readFile('.claude/session/input.json');

// Sub-agent writes output file
writeFile('.claude/session/output.json', result);

// Parent agent reads output file
const result = readFile('.claude/session/output.json');
```

## Output Templates

### Template Locations

```
.claude/templates/
├── research-output-template.json      # pm-research-specialist output
├── gdd-output-template.json            # thermite-facilitator output
├── prd-starter-state-template.json    # State file structure
└── SUBAGENT_TEMPLATE.md               # Sub-agent definition template
```

### Using Output Templates

**Sub-Agent Frontmatter:**
```yaml
---
name: pm-research-specialist
outputTemplate: .claude/templates/research-output-template.json
---
```

**Sub-Agent Instructions:**
```markdown
## Output Format

Your output MUST match the structure defined in:
`.claude/templates/research-output-template.json`

Key fields to populate:
- `researchData.similarProjects` - Array of similar projects found
- `researchData.bestPractices` - Array of best practices discovered
- `researchData.questionsAsked` - Array of clarifying questions for user
- `researchData.references` - Array of reference URLs
```

## Validation Checklist

### Before Invoking Sub-Agent

- [ ] State file exists and is readable
- [ ] Required state fields are populated
- [ ] Sub-agent `.agent.md` file exists
- [ ] Sub-agent has required tools
- [ ] Prompt includes all necessary context

### After Sub-Agent Completion

- [ ] Output matches expected template structure
- [ ] Required fields are present and populated
- [ ] State file updated successfully
- [ ] No errors in `generationResults.errors`
- [ ] User has been presented with summary

### State File Health

- [ ] `currentPhase` reflects actual position
- [ ] `lastModified` is current timestamp
- [ ] JSON structure is valid
- [ ] No circular references
- [ ] All arrays are properly formatted

## Example: Complete Phase 8b Flow

### Parent Agent (prd-starter)

```markdown
## Phase 8b: Deep Research

After collecting initial features, launch research specialist.

**Step 1: Prepare state**
Read `.claude/session/prd-starter-state.json` and extract:
- project.name, project.description, project.category
- features array

**Step 2: Invoke sub-agent**
```
Task("pm-research-specialist", {
  prompt: `Research this project deeply:
  Project: ${state.project.name}
  Description: ${state.project.description}
  Category: ${state.project.category}
  Tech Stack: ${state.project.techStack}
  Features: ${features.join(', ')}

  Return structured output matching research-output-template.json`
})
```

**Step 3: Process results**
- Parse returned researchData
- Update state file with researchData
- Set currentPhase to "user_questions"
- Write state file

**Step 4: Present to user**
Display research findings and ask clarifying questions.
Store answers in researchData.questionsAnswered.
```

### Sub-Agent (pm-research-specialist)

```markdown
## Process

1. **Receive input** from prompt
2. **Research** using WebSearch, GitHub exploration
3. **Structure output** matching template
4. **Return** formatted response

## Response

```json
{
  "researchData": {
    "similarProjects": [...],
    "bestPractices": [...],
    "questionsAsked": [...],
    "references": [...]
  }
}
```
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Sub-agent not found | `.agent.md` file missing | Verify file exists at `.claude/agents/{name}.agent.md` |
| Invalid state file | JSON syntax error | Validate JSON, check for trailing commas |
| Missing output | Sub-agent didn't return expected format | Check output template reference |
| Phase not advancing | currentPhase not updated | Ensure parent agent updates state after each phase |
| Circular dependency | Sub-agents calling each other | Restrict to parent→child calls only |

## Best Practices

1. **Single Responsibility** - Each sub-agent has one clear purpose
2. **Read-Only by Default** - Sub-agents should be read-only unless writing is necessary
3. **Structured Output** - Always use defined templates for output
4. **State Immutability** - Only modify designated state fields
5. **Error Recovery** - Always provide recovery options
6. **User Visibility** - Present summaries at each phase transition
7. **Resumable** - State file enables resuming from any phase

## See Also

- [SUBAGENT_TEMPLATE.md](.claude/templates/SUBAGENT_TEMPLATE.md) - Sub-agent definition template
- [prd-starter-state-template.json](.claude/templates/prd-starter-state-template.json) - State file structure
- [prd-starter.agent.md](.claude/agents/prd-starter.agent.md) - Parent agent using sub-agents
