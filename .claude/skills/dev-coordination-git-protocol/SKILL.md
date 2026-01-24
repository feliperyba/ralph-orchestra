---
name: git-protocol
description: Git commit format and branch management
category: coordination
keywords: [git, commit, branch, worktree]
---

# Git Protocol

Git workflow for the Ralph developer agent.

## Commit Format

All commits MUST use this format:

```
[ralph] [developer] {taskId}: Brief description

- Change 1
- Change 2

PRD: {taskId} | Agent: developer | Iteration: N
```

### Example

```
[ralph] [developer] feat-001: Player movement with WASD

- Add WASD input handling
- Implement velocity-based movement
- Add diagonal movement normalization

PRD: feat-001 | Agent: developer | Iteration: 1
```

## Worktree Branch

Developer commits go to the `developer-worktree` branch, not `main`.

### Workflow

```bash
# After implementation is complete:
git add .
git commit -m "[ralph] [developer] {taskId}: {description}"
git push origin developer-worktree
```

### Why Worktree?

- Allows parallel development with other agents
- Prevents merge conflicts
- QA validates from worktree before merging to main

## Branch Flow

```
developer-worktree (Developer commits here)
    ↓ QA validation passes
main (QA merges here)
```

## After QA Passes

QA handles merging `developer-worktree` → `main`. Developer does NOT merge.

## Merging Latest Main

Before starting new work:

```bash
git fetch origin main
git rebase origin/main
```

This keeps worktree up to date with main.

## Git Hygiene

- [ ] Commit messages follow format
- [ ] Pushed to developer-worktree
- [ ] No merge conflicts
- [ ] Clean working directory
