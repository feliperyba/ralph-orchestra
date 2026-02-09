# Thermite Hookify Rules

These rules enforce structured design sessions and artifact generation. Place in `.claude/` directory of your thermite project.

---

## Rule: Session Output Reminder

**File:** `.claude/hookify.thermite-session-end.local.md`

```markdown
---
name: thermite-session-end
enabled: true
event: stop
conditions:
  - field: transcript
    operator: contains
    pattern: (Session \d|Boardroom|Creative Team|design session|retreat)
action: warn
---

## 📋 Thermite Session Checklist

Before ending this design session, ensure you've captured:

- [ ] **Decisions Made** → Append to `decision_log.md`
- [ ] **Open Questions** → Append to `open_questions.md`
- [ ] **Artifacts Updated** → List which docs changed
- [ ] **Action Items** → With owners assigned
- [ ] **Next Session Topic** → What's queued

Run `/thermite export` to generate session summary artifact.
```

---

## Rule: Decision Format Enforcement

**File:** `.claude/hookify.thermite-decision-format.local.md`

```markdown
---
name: thermite-decision-format
enabled: true
event: file
conditions:
  - field: file_path
    operator: regex_match
    pattern: decision_log\.md$
  - field: new_text
    operator: not_contains
    pattern: \*\*Status:\*\*
action: warn
---

## ⚠️ Decision Log Format Required

Decisions must include:
- **ID:** DEC-[NNN]
- **Status:** Decided | Tentative | Revisit After Playtest
- **Pillar(s):** Which design pillars this serves
- **Context:** Why this came up
- **Decision:** What was chosen
- **Alternatives Considered:** What was rejected
- **Dissent:** Concerns raised and how addressed

Use the decision template from `references/artifact_templates.md`
```

---

## Rule: Pillar Check Reminder

**File:** `.claude/hookify.thermite-pillar-check.local.md`

```markdown
---
name: thermite-pillar-check
enabled: true
event: prompt
conditions:
  - field: user_prompt
    operator: regex_match
    pattern: (decide|final|ship|implement|build this|let's do)
action: warn
---

## 🎯 Pillar Check Required

Before finalizing, verify against all 5 pillars:

1. **Meaningful Risk** - Does this preserve stakes?
2. **Readable Chaos** - Is this instantly parseable?
3. **Compressed Tension** - Does this respect 5-8 min target?
4. **Earned Mastery** - Does skill beat gear?
5. **Sustainable Economy** - Is this exploitable? Patchable?

If ANY pillar is violated, discuss before proceeding.
```

---

## Rule: Gear Registry Format

**File:** `.claude/hookify.thermite-gear-format.local.md`

```markdown
---
name: thermite-gear-format
enabled: true
event: file
conditions:
  - field: file_path
    operator: regex_match
    pattern: gear_registry\.md$
  - field: new_text
    operator: not_contains
    pattern: \*\*Counterplay\*\*
action: warn
---

## ⚔️ Gear Entry Requires Counterplay

Every gear item MUST define:
- **Countered by:** What beats this
- **Counters:** What this beats

No item ships without counterplay analysis. See Marcus Chen's design philosophy:
> "What beats this? If nothing beats this, it ships broken."
```

---

## Rule: Red Flag Detection

**File:** `.claude/hookify.thermite-red-flags.local.md`

```markdown
---
name: thermite-red-flags
enabled: true
event: prompt
conditions:
  - field: user_prompt
    operator: regex_match
    pattern: (would be cool but|players won't|balance it later|just like .+ but|fine if.+unfair)
action: warn
---

## 🚩 Red Flag Detected

Your message contains a known design trap:

- **"This would be cool but..."** → Scope creep alert
- **"Players won't do that..."** → They absolutely will
- **"We can balance it later..."** → No, you can't
- **"Just like [AAA game] but..."** → Resource mismatch
- **"It's fine if it's a little unfair..."** → Pillar violation

Pause and reconsider before proceeding.
```

---

## Rule: Persona Attribution

**File:** `.claude/hookify.thermite-persona-attribution.local.md`

```markdown
---
name: thermite-persona-attribution
enabled: true
event: file
conditions:
  - field: file_path
    operator: regex_match
    pattern: (decision_log|session_).*\.md$
  - field: new_text
    operator: not_contains
    pattern: (Shinji|Viktor|Elena|Marcus|Sarah|Maya|Wei|Jordan)
action: warn
---

## 👥 Persona Attribution Missing

Design decisions should reference which team member perspective drove them:

- **Shinji Tanaka** - Arcade design
- **Viktor Volkov** - Extraction/economy
- **Elena Vasquez** - Map architecture
- **Marcus Chen** - Combat balance
- **Sarah Okonkwo** - Economy
- **Dr. Maya Reyes** - Player psychology
- **Wei Zhang** - Technical feasibility
- **Jordan Ellis** - UX/accessibility

Attribute insights and dissent to specific personas for traceability.
```

---

## Rule: MVD Blocker Check

**File:** `.claude/hookify.thermite-mvd-check.local.md`

```markdown
---
name: thermite-mvd-check
enabled: true
event: prompt
conditions:
  - field: user_prompt
    operator: regex_match
    pattern: (start building|begin prototype|write code|implement)
action: warn
---

## 🚧 MVD Checklist Gate

Before starting implementation, verify MVD completion:

**Must Have (All Required):**
- [ ] Core loop documented
- [ ] Grid contract defined
- [ ] Loadout system scoped
- [ ] Death rules codified
- [ ] Map template exists
- [ ] Extraction mechanic specified
- [ ] AI presence decided

Run `check_mvd.py` to see current status.

If items are incomplete, schedule design sessions to resolve them first.
```

---

## Installation

1. Create `.claude/` directory in thermite project root
2. Copy each rule block above into its own file with the specified filename
3. Verify rules are active: `/hookify list`

## Customization

Adjust `enabled: true/false` to toggle rules without deleting them.

Modify patterns to match your team's language and workflow.
