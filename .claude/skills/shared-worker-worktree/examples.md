# Worktree Examples

This file contains practical examples of using git worktrees with Ralph Orchestra agents.

> **Note:** All examples use relative paths (like `../developer-worktree`) which work regardless of what you name your project folder.

---

## Example 1: First-Time Worktree Setup

**Scenario:** Developer agent needs to work in parallel with Tech Artist.

```bash
# From your project root (regardless of folder name)
# Check existing worktrees
git worktree list

# Create developer worktree if it doesn't exist
git worktree add ../developer-worktree -b developer-worktree

# Create techartist worktree if it doesn't exist
git worktree add ../techartist-worktree -b techartist-worktree

# Verify both are created
git worktree list
# Output should show:
# /path/to/your-project            main
# /path/to/your-project/../developer-worktree  developer-worktree
# /path/to/your-project/../techartist-worktree  techartist-worktree
```

---

## Example 2: Daily Agent Workflow

**Scenario:** Developer agent starting a new task.

```bash
# 1. Navigate to worktree (relative path - works from any folder name)
cd ../developer-worktree

# 2. Get latest changes from main
git fetch origin main
git merge origin/main

# 3. Start working on the task
# ... (agent does its work, edits files, runs tests) ...

# 4. Commit changes in worktree
git add .
git commit -m "feat: implement user authentication"
git push origin developer-worktree

# 5. Signal ready for QA validation
# (Agent sends message to PM indicating work complete)
```

---

## Example 3: QA Merge Protocol

**Scenario:** QA agent validates Developer's work and merges to main.

```bash
# QA works in main directory (no worktree needed)
# Stay in the current project root

# 1. Switch to main branch (if not already on main)
git checkout main

# 2. Get latest changes
git pull origin main

# 3. Fetch and merge developer's worktree branch
git fetch origin developer-worktree
git merge origin/developer-worktree

# 4. Run validation tests
npm test
npm run build

# 5. If validation passes, push merged changes
git push origin main

# 6. Notify Developer that their work was merged
# (QA sends message to PM/Developer)
```

---

## Example 4: Handling Merge Conflicts

**Scenario:** Worktree merge has conflicts from main.

```bash
# In the worktree directory
cd ../developer-worktree

# Fetch and attempt merge
git fetch origin main
git merge origin/main

# If conflicts occur:
# 1. See conflict files
git status

# 2. Edit conflicted files to resolve conflicts
# (Use code editor to fix the conflicts)

# 3. Mark conflicts as resolved
git add <resolved-files>

# 4. Complete the merge
git commit -m "Merge main into developer-worktree"

# 5. Continue working
```

---

## Example 5: Parallel Work Session

**Scenario:** Developer and Tech Artist working simultaneously.

```bash
# Terminal 1 - Developer Agent
cd ../developer-worktree
git merge origin/main
# ... Developer works on src/components/Game.tsx ...
git add src/components/Game.tsx
git commit -m "feat: add game logic component"
git push origin developer-worktree

# Terminal 2 - Tech Artist Agent (simultaneously)
cd ../techartist-worktree
git merge origin/main
# ... Tech Artist works on src/assets/materials/water.ts ...
git add src/assets/materials/water.ts
git commit -m "feat: add water material"
git push origin techartist-worktree

# Both can work independently - no file conflicts!
# Only when they edit the SAME file would coordination be needed
```

---

## Example 6: Worktree Cleanup After Completion

**Scenario:** Task is complete, work is merged to main, clean up worktree.

```bash
# 1. Switch back to main directory
cd ..  # Return to project root
git checkout main

# 2. Verify worktree branch was merged
git branch --merged | grep developer-worktree

# 3. If merged, remove local branch
git branch -d developer-worktree

# 4. Remove the worktree
git worktree remove ../developer-worktree

# 5. Verify cleanup
git worktree list
# Should only show main directory
```

---

## Example 7: Checking Worktree Status

**Scenario:** Agent needs to know current worktree state.

```bash
# List all worktrees
git worktree list

# Output example:
# /current/absolute/path/to/your-project            abc1234 [main]
# /current/absolute/path/../developer-worktree  def5678 [developer-worktree]
# /current/absolute/path/../techartist-worktree  ghi9012 [techartist-worktree]

# Check current branch and location
pwd                    # Shows current directory
git branch --show-current  # Shows current branch

# Check for changes in worktree
cd ../developer-worktree
git status
```

---

## Example 8: Troubleshooting

### Problem: Worktree at wrong path

```bash
# Remove worktree from wrong location
git worktree remove ../old-wrong-path

# Recreate at correct path
git worktree add ../developer-worktree -b developer-worktree
```

### Problem: Orphaned worktree branch

```bash
# After worktree is removed, branch might still exist
git branch -a | grep developer-worktree

# Delete orphaned branch (if merged to main)
git branch -d developer-worktree

# Force delete if not merged (use with caution)
git branch -D developer-worktree
```

### Problem: Worktree out of sync with main

```bash
# In the worktree
cd ../developer-worktree

# Hard reset to match main (CAUTION: discards local changes)
git fetch origin main
git reset --hard origin/main
```

---

## Key Points

1. **Relative paths work everywhere** - `../developer-worktree` works regardless of your project folder name
2. **Worktrees are isolated** - Each agent works in their own directory without conflicts
3. **Main is for QA** - QA agent validates in main directory before merging
4. **Merge through main** - Work gets merged to main, other worktrees pull from main
5. **Clean up after completion** - Remove worktrees after tasks are done and merged
