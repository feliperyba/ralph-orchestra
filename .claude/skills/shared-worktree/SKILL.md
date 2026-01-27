---
name: worker-worktree
description: Git worktree setup and management for parallel agent development. Use when working in isolated git worktrees to avoid merge conflicts between Developer and Tech Artist agents.
category: workflow
---

# Worker Worktree Skill

> "Parallel development without conflicts – each agent works in their own worktree."

## What Are Git Worktrees

Git worktrees allow multiple working directories to be linked to a single repository. Each worktree can have its own branch checked out, enabling parallel development without file conflicts.

**Why use worktrees for agents?**

- Developer and Tech Artist can work simultaneously
- No file-level conflicts when editing different files
- Isolated testing environments
- Cleaner git history with feature branches

## Worktree Naming Convention

**MUST follow this pattern:** `{agent}-worktree`

| Agent       | Worktree Name         | Worktree Path            | Branch Name           |
| ----------- | --------------------- | ------------------------ | --------------------- |
| Developer   | `developer-worktree`  | `../developer-worktree`  | `developer-worktree`  |
| Tech Artist | `techartist-worktree` | `../techartist-worktree` | `techartist-worktree` |
| QA          | Uses main worktree    | . (current directory)    | main                  |

## Initial Setup (One-Time Per Agent)

**⚠️ Run ONLY once per agent, on first startup:**

```bash
# Check if worktree already exists
git worktree list

# If NOT in list, create worktree with dedicated branch
git worktree add ../{agent}-worktree -b {agent}-worktree

# Verify creation
git worktree list
```

**Example for Developer agent:**

```bash
git worktree add ../developer-worktree -b developer-worktree
```

**Example for Tech Artist agent:**

```bash
git worktree add ../techartist-worktree -b techartist-worktree
```

## Daily Workflow

### Before Starting ANY Task

```bash
# 1. Navigate to your worktree
cd ../{agent}-worktree

# 2. Merge latest changes from main
git fetch origin main
git merge origin/main

# 3. Resolve any merge conflicts if they occur
git status

# 4. Start working
```

**Why merge main first?**

- Ensures you have the latest changes from the other agent's work
- Prevents out-of-date code conflicts
- Both agents' work gets integrated through main

### While Working

All work happens in the worktree directory:

- Edit files
- Run feedback loops
- Commit changes
- Create feature branches from worktree if needed

### After Committing

```bash
# All commits go to your worktree branch automatically
git push origin {agent}-worktree
```

## Unit, E2E, and Playwright MCP Testing Protocol

Remember to always run the tests in the target worktree branches for validation

- Move to the target worktree
- Load the correct skills for this scope
- Run validation process
- During validation process, always double check in which port the client is running for proper URL check
- Investigate in case of issues and iterate until fixed

## QA Merge Protocol

**QA Agent ONLY:**

### When Validation PASSES

```bash
# 1. Switch to main branch
git checkout main

# 2. Fetch and merge agent worktree branch
git fetch origin {agent}-worktree
git merge origin/{agent}-worktree

# 3. Push merged changes to origin
git push origin main

# 4. Return to main for next task
# (Stay on main - worktree is clean for next agent work)
```

### When Validation FAILS

```bash
# DO NOT MERGE
# Send bug_report back to agent
# Agent will fix in their worktree
# No changes to main branch
```

## Best Practices

✅ **DO:**

- Always merge main before starting work
- Commit frequently in your worktree
- Push worktree branch after each commit
- Resolve merge conflicts promptly
- Keep worktree branch clean (delete merged commits)

❌ **DON'T:**

- Create worktree if one already exists
- Work in main directory (use your worktree)
- Merge to main yourself (QA does this after validation)
- Delete worktree without QA approval
- Commit directly to main from worktree

## Master Branch Coordination (CRITICAL)

**THE GOLDEN RULE:** Worktrees are for CODE/ASSETS ONLY. All coordination happens in master.

### What Goes Where

| Operation             | Location        | Why                                  |
| --------------------- | --------------- | ------------------------------------ |
| **PRD updates**       | Master branch   | PM needs to see status immediately   |
| **Sending messages**  | Master branch   | Watchdog only watches master session |
| **Reading messages**  | Master branch   | All coordination messages live here  |
| **Heartbeat updates** | Master branch   | Watchdog monitors master PRD         |
| **Code commits**      | Worktree branch | Isolated development, QA validates   |
| **Asset creation**    | Worktree branch | Isolated development, QA validates   |

### The Workflow

```
1. Developer in worktree:
   ├── Reads PRD from master (Get-MasterPrdPath)
   ├── Reads messages from master (Get-MasterMessageQueuePath)
   ├── Updates PRD status in master (atomic write)
   ├── Sends messages to master queue
   ├── Writes code in worktree (src/)
   ├── Commits code to worktree branch
   └── Sends validation_request via master queue

2. PM in master:
   ├── Reads PRD (sees worker status updates)
   ├── Reads messages (sees worker messages)
   └── Coordinates everything

3. QA in master:
   ├── Navigates to worktree for testing
   ├── If validation passes: merges to master
   └── If validation fails: sends bug_report via master queue
```

### Master Branch Path Resolution

When working in a worktree, coordination files MUST be accessed from the master branch:

```bash
# From worktree, master branch prd.json is typically at:
../agentic-threejs/prd.json  (if worktree is sibling to master)

# Or determine path by navigating up from worktree to master root
# Use relative paths to access master branch coordination files
```

### Example: Complete Status Update

```bash
# Use Read/Edit tools for bash-safe PRD updates

# Step 1: Read master PRD from worktree
Read("../agentic-threejs/prd.json")

# Step 2: Use Edit tool to update status
# Edit tool handles atomic writes automatically
# Updates to agent status, task status, heartbeat, etc.

# The Edit tool writes atomically - no need for manual temp file pattern
```

## File Conflict Prevention

Worktrees prevent conflicts at the **file level**, but agents should still coordinate:

| Developer Works In        | Tech Artist Works In               |
| ------------------------- | ---------------------------------- |
| `src/components/` (logic) | `src/components/` (materials only) |
| `src/hooks/`              | `src/assets/`                      |
| `src/stores/`             | `src/styles/`                      |
| `src/server/`             | `src/vfx/`                         |
| `src/utils/`              | `public/textures/`                 |
| Test files                | Visual test files                  |

**If both need to edit the same file:**

- PM assigns tasks sequentially (not parallel)
- First agent completes, QA validates, merges to main
- Second agent then starts (pulls from main)

## Troubleshooting

### Worktree Already Exists

```bash
git worktree list
# Output shows:
# /path/to/main               main
# /path/to/developer-worktree developer-worktree

# If listed, just cd to it:
cd ../developer-worktree
```

### Merge Conflicts from Main

```bash
# In your worktree:
cd ../{agent}-worktree
git fetch origin main
git merge origin/main

# If conflicts occur:
# 1. Edit conflicted files
# 2. git add <resolved-files>
# 3. git commit -m "Merge main into {agent}-worktree"
```

### Worktree Needs Removal

**Only after QA approval and all work is complete:**

```bash
# 1. Ensure worktree branch is merged to main
git checkout main
git branch -d {agent}-worktree  # Only if merged

# 2. Remove worktree
git worktree remove ../{agent}-worktree
```

### Worktree Path Issues

If worktree is at wrong path:

```bash
# Remove existing worktree
git worktree remove ../{agent}-worktree

# Recreate at correct path
git worktree add ../{agent}-worktree -b {agent}-worktree
```

## Verification Checklist

Before starting work:

- [ ] Worktree exists (`git worktree list` shows your worktree)
- [ ] In worktree directory (`pwd` shows `../{agent}-worktree`)
- [ ] On correct branch (`git branch` shows `{agent}-worktree`)
- [ ] Main branch merged (`git merge origin/main` completed)
- [ ] No merge conflicts (`git status` is clean)
- [ ] Latest changes pulled (`git log` shows recent main commits)

## Quick Reference Commands

| Action               | Command                                                    |
| -------------------- | ---------------------------------------------------------- |
| List worktrees       | `git worktree list`                                        |
| Create worktree      | `git worktree add ../{agent}-worktree -b {agent}-worktree` |
| Remove worktree      | `git worktree remove ../{agent}-worktree`                  |
| Navigate to worktree | `cd ../{agent}-worktree`                                   |
| Merge main           | `git fetch origin main && git merge origin/main`           |
| Push worktree        | `git push origin {agent}-worktree`                         |
| Check current branch | `git branch --show-current`                                |
