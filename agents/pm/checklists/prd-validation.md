---
name: prd-validation
description: Checklist for validating PRD items before task assignment
category: validation
---

# PRD Validation Checklist

## Required Fields

| Field                | Required | Type    | Description                                                             |
| -------------------- | -------- | ------- | ----------------------------------------------------------------------- |
| `id`                 | ✅       | string  | Unique identifier (e.g., `feat-001`)                                    |
| `title`              | ✅       | string  | Short descriptive title                                                 |
| `description`        | ✅       | string  | Full task specification                                                 |
| `category`           | ✅       | enum    | `architectural` \| `integration` \| `spike` \| `functional` \| `polish` |
| `priority`           | ✅       | enum    | `high` \| `medium` \| `low`                                             |
| `acceptanceCriteria` | ✅       | array   | Testable criteria (min 1)                                               |
| `verificationSteps`  | ✅       | array   | Steps for QA to verify (min 1)                                          |
| `dependencies`       | ⚠️       | array   | Task IDs (can be empty `[]`)                                            |
| `agent`              | ⚠️       | string  | Target agent (default: `developer`)                                     |
| `passes`             | ⚠️       | boolean | Completion status (default: `false`)                                    |
| `status`             | ⚠️       | string  | Current status (default: `pending`)                                     |

## Pre-Assignment Checklist

- [ ] **ID exists and is unique**
- [ ] **Title is descriptive** (not just "Feature 1")
- [ ] **Description is actionable** (developer can start work)
- [ ] **Category is valid** (one of: architectural, integration, spike, functional, polish)
- [ ] **Priority is set** (high, medium, or low)
- [ ] **At least 1 acceptance criterion** (testable)
- [ ] **At least 1 verification step** (QA can follow)
- [ ] **Dependencies array exists** (even if empty)
- [ ] **All dependencies have `passes: true`**

## Minimal Valid PRD Item

```json
{
  "id": "feat-001",
  "title": "Feature Title",
  "description": "What needs to be done",
  "category": "functional",
  "priority": "medium",
  "acceptanceCriteria": ["Criterion 1"],
  "verificationSteps": ["Step 1"],
  "dependencies": [],
  "passes": false
}
```

## Invalid Task Actions

If a task fails validation:

1. **DO NOT** assign the task
2. Log warning to `coordinator-progress.txt`:
   ```markdown
   ### [TIMESTAMP] PRD Validation Failed: {{TASK_ID}}

   Missing fields: {{field_list}}
   Action: Skipped - requires manual fix
   ```
3. Skip to next valid task
4. Consider fixing the PRD item description if you can

## Common Issues

| Issue                        | Solution                              |
| ---------------------------- | ------------------------------------- |
| Missing `acceptanceCriteria` | Add at least one testable criterion   |
| Empty `description`          | Add actionable implementation details |
| Invalid `category`           | Use one of the 5 valid categories     |
| Circular dependencies        | Remove or reorder dependencies        |
| Unmet dependencies           | Wait for dependent tasks to pass      |
