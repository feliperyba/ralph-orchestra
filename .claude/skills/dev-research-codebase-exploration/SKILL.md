---
name: codebase-exploration
description: Efficient codebase search using Glob and Grep
category: research
---

# Codebase Exploration

> "Start broad, then narrow - understand before you implement."

## When to Use This Skill

Use when:
- Starting a new feature implementation
- Looking for existing patterns
- Understanding how features are organized
- Finding where to add new code
- Before writing any implementation

## Quick Start

```bash
# Step 1: Find relevant files with Glob
Glob("src/components/**/*.tsx")

# Step 2: Search for patterns with Grep
Grep("useFrame", "src/")

# Step 3: Read similar implementations
Read("src/components/AnimatedMesh.tsx")
```

## Decision Framework

| Need | Tool | Pattern |
|------|------|---------|
| Find file types | Glob | `**/*.tsx` |
| Find in specific folder | Glob | `src/components/**/*.tsx` |
| Find by keyword | Glob | `**/*player*` |
| Search code content | Grep | `Grep("pattern", "src/")` |
| Case-insensitive | Grep | `{ ignoreCase: true }` |
| Get context | Grep | `{ context: 3 }` |

## Progressive Guide

### Level 1: Basic File Finding

```bash
# Find all TypeScript files
Glob("**/*.ts")

# Find all TSX files
Glob("**/*.tsx")

# Find all test files
Glob("**/*.test.ts")
Glob("**/*.spec.ts")
```

### Level 2: Targeted Folder Search

```bash
# Search specific directories
Glob("src/components/**/*.tsx")
Glob("src/hooks/**/*.ts")
Glob("src/stores/**/*.ts")
Glob("server/rooms/**/*.ts")

# Find configuration files
Glob("**/*.config.{ts,js}")
Glob("**/tsconfig.json")
```

### Level 3: Keyword-Based Search

```bash
# Find files with keyword in name
Glob("**/*player*")
Glob("**/*physics*")
Glob("**/*network*")

# Combine with folder patterns
Glob("src/**/*Scene*.ts")
Glob("server/**/*Room*.ts")
```

### Level 4: Content-Based Pattern Search

```bash
# Search for specific patterns in code
Grep("useFrame", "src/")
Grep("useState", "src/")
Grep("createRoom", "server/")

# Case-insensitive search
Grep("colyseus", "src/", { ignoreCase: true })

# Search with context lines
Grep("function.*movement", "src/", { context: 2 })
```

### Level 5: Advanced Pattern Discovery

```bash
# Find component definitions
Grep("function.*Component|const.*=.*=>", "src/components/")

# Find state stores
Grep("create.*Store|zustand", "src/stores/")

# Find type definitions
Grep("interface.*|type.*=", "src/types/")

# Find exports
Grep("export.*function|export.*const", "src/")

# Find imports to understand dependencies
Grep("import.*from", "src/components/Player.tsx", { context: 0 })
```

## Common Pitfalls

| Pitfall | Why It's Wrong | Correct Approach |
|---------|----------------|------------------|
| Too broad pattern | Returns too many results | Be specific with folder paths |
| Only searching one place | Code might be elsewhere | Check multiple locations |
| Not reading results | Misses context | Read 2-3 similar files |
| Ignoring test files | Tests show usage patterns | Include tests in search |
| Case-sensitive when unsure | Misses variations | Use `{ ignoreCase: true }` |

## Code Patterns

### Framework Pattern Discovery

**R3F Pattern Search:**
```bash
# Find R3F components
Grep("useFrame|Canvas|mesh", "src/")

# Find drei usage
Grep("from '@react-three/drei'", "src/")

# Find 3D asset loading
Grep("useGLTF|useFBX|useTexture", "src/")
```

**Phaser Pattern Search:**
```bash
# Find Phaser scenes
Grep("extends Phaser.Scene", "src/")

# Find preload patterns
Grep("preload.*load", "src/")

# Find physics usage
Grep("arcade.*physics|matter.*physics", "src/")
```

**Multiplayer Pattern Search:**
```bash
# Find Colyseus rooms
Grep("extends Room", "server/")

# Find state schema definitions
Grep("@type|SchemaDecorator", "server/")

# Find client connection
Grep("joinOrCreate|client\.join", "src/")
```

### Research Workflow Template

```xml
<research_workflow>
1. Identify feature category (R3F, Phaser, Multiplayer, etc.)
2. Use Glob to find relevant files in category folders
3. Use Grep to find pattern usage in those files
4. Read 2-3 most relevant implementations
5. Document findings:
   - File paths with line numbers
   - Key patterns observed
   - Dependencies used
   - Testing approach
</research_workflow>
```

## Multishot Examples

### Example 1: Finding R3F Animation Patterns

```bash
# Step 1: Find R3F component files
Glob("src/components/**/*.tsx")

# Step 2: Search for useFrame usage
Grep("useFrame", "src/components/", { context: 3 })

# Step 3: Read a specific animated component
Read("src/components/SpinningCube.tsx")

# Result: Found pattern using ref + delta for frame-independent animation
```

### Example 2: Finding Phaser Scene Structure

```bash
# Step 1: Find all scene files
Glob("src/scenes/**/*.ts")

# Step 2: Search for scene class definitions
Grep("class.*Scene", "src/scenes/")

# Step 3: Read a scene implementation
Read("src/scenes/GameScene.ts")

# Result: Found pattern with preload(), create(), update() methods
```

### Example 3: Finding State Management Approach

```bash
# Step 1: Check for stores
Glob("src/stores/**/*.ts")

# Step 2: Search for store patterns
Grep("create|zustand", "src/stores/")

# Step 3: Read store implementation
Read("src/stores/gameStore.ts")

# Result: Found Zustand pattern with actions and selectors
```

### Example 4: Understanding Type Definitions

```bash
# Step 1: Find type files
Glob("src/types/**/*.ts")

# Step 2: Search for specific interfaces
Grep("interface Player|interface GameState", "src/types/")

# Step 3: Read type definitions
Read("src/types/index.ts")

# Result: Found centralized type definitions with exports
```

### Example 5: Finding Test Patterns

```bash
# Step 1: Find test files
Glob("**/*.test.ts")

# Step 2: Search for test patterns
Grep("describe|test|expect", "tests/", { context: 1 })

# Step 3: Read similar test
Read("tests/components/Player.test.ts")

# Result: Found vitest pattern with describe/test/expect
```

## Anti-Patterns

**DON'T:**

- Search entire codebase with broad patterns (`Grep("function", "./")`)
- Skip reading the actual files after finding them
- Assume code structure without verifying
- Only search one location (code may be organized differently)
- Ignore test files (they show usage patterns)

**DO:**

- Start with specific folder patterns
- Read 2-3 similar implementations
- Document findings with file:line references
- Check multiple locations for patterns
- Include tests in your research

## Tips

1. **Start broad, then narrow** - Use Glob first, then Grep
2. **Use specific patterns** - More specific = faster results
3. **Check multiple locations** - Code may be in unexpected places
4. **Read related files** - Found patterns often have related code nearby
5. **Document as you go** - Note file paths and line numbers
6. **Look for tests** - Tests show how code is actually used
7. **Check imports** - Imports reveal dependencies and structure

## Search Patterns Reference

| Find | Command |
|------|---------|
| All TS files | `Glob("**/*.ts")` |
| All TSX files | `Glob("**/*.tsx")` |
| Component files | `Glob("src/components/**/*.tsx")` |
| Hook files | `Glob("src/hooks/**/*.ts")` |
| Store files | `Glob("src/stores/**/*.ts")` |
| Type definitions | `Glob("src/types/**/*.ts")` |
| Test files | `Glob("**/*.test.ts")` |
| Files with keyword | `Glob("**/*player*")` |
| Pattern in code | `Grep("useFrame", "src/")` |
| Case-insensitive | `Grep("COLYSEUS", "src/", { ignoreCase: true })` |
| With context | `Grep("function.*movement", "src/", { context: 2 })` |

## See Also

- [dev-research-pattern-finding](../dev-research-pattern-finding/SKILL.md) — Find specific code patterns
- [dev-research-gdd-reading](../dev-research-gdd-reading/SKILL.md) — Read design documents
- [dev-router](../dev-router/SKILL.md) — Route to appropriate skills by category
