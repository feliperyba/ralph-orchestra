---
name: pattern-finding
description: Find existing code patterns before implementing new features
category: research
---

# Pattern Finding

> "Don't reinvent - discover patterns first, implement second."

## When to Use This Skill

Use when:
- Starting any implementation work
- Need to understand how similar features work
- Looking for established patterns to follow
- Unsure where to place new code
- **MANDATORY** before writing new code

## Quick Start

```bash
# Step 1: Identify key terms from task
# Task: "Implement player health bar"
# Key terms: "player", "health", "bar"

# Step 2: Search for similar code
Glob("**/*player*")
Grep("health", "src/")

# Step 3: Read and analyze patterns
Read("src/components/Player.tsx")
```

## Decision Framework

| Need | Search Strategy |
|------|-----------------|
| Similar feature | Glob by keyword |
| Component pattern | Glob "src/components/**/*.tsx" |
| Hook pattern | Glob "**/hooks/*.ts" |
| Usage pattern | Grep for function name |
| Import pattern | Grep "import.*from" in similar files |
| State pattern | Grep "useState|useStore" |

## Progressive Guide

### Level 1: Basic Pattern Discovery

```bash
# Find files by keyword
Glob("**/*player*")
Glob("**/*health*")

# Search code content
Grep("health", "src/")
```

### Level 2: Component Structure Analysis

```bash
# Find component files
Glob("src/components/**/*.tsx")

# Read a similar component
Read("src/components/Player.tsx")

# Look for:
# - Functional or class component
# - Props interface
# - Hooks used
# - State management approach
```

### Level 3: State Pattern Discovery

```bash
# Find state stores
Glob("src/stores/**/*.ts")

# Search for state usage
Grep("useStore|getState|setState", "src/")

# Analyze store pattern
Read("src/stores/gameStore.ts")
```

### Level 4: Framework-Specific Patterns

**R3F:**
```bash
Grep("useFrame|Canvas|mesh", "src/")
Grep("from '@react-three/drei'", "src/")
```

**Phaser:**
```bash
Grep("extends Phaser.Scene", "src/")
Grep("preload|create|update", "src/scenes/")
```

**Multiplayer:**
```bash
Grep("@type|SchemaDecorator", "server/")
Grep("room\.send|onMessage", "src/")
```

### Level 5: Cross-Feature Pattern Analysis

```bash
# Find how multiple features integrate
Grep("import.*Player", "src/")
Grep("from.*player", "src/")

# Read integration points
Read("src/scenes/GameScene.ts")
Read("src/stores/gameStore.ts")

# Document:
# - How components connect
# - Data flow patterns
# - Event handling patterns
```

## What to Look For

| Pattern Type | What to Check | Examples |
|--------------|---------------|----------|
| **Import patterns** | Module imports | `import { mesh } from '@react-three/fiber'` |
| **Component structure** | Functional vs class | `function Component()` vs `class Component` |
| **Props interface** | Type definitions | `interface Props { ... }` |
| **Hooks used** | React hooks | `useState`, `useEffect`, `useFrame` |
| **State management** | How state flows | Zustand, Context, local state |
| **API patterns** | External calls | `fetch()`, `room.send()` |
| **Error handling** | Try/catch usage | `try { ... } catch (e) { ... }` |
| **File organization** | Where code lives | `src/components/`, `src/hooks/` |
| **Testing patterns** | Test structure | `describe()`, `test()`, `expect()` |
| **Export patterns** | How modules export | `export function`, `export default` |

## Pattern Documentation Template

```markdown
## Pattern: {pattern name}

**Found in:** `{file paths}`

**Usage:** {brief description of how pattern is used}

### Key Elements
- {element 1 with file:line reference}
- {element 2 with file:line reference}
- {element 3 with file:line reference}

### Import Pattern
```typescript
// How dependencies are imported
import { ... } from '...'
```

### Structure
```typescript
// Code structure pattern
interface Props { ... }
function Component({ ... }: Props) {
  // ...
}
```

### State Management
```typescript
// How state is managed
const state = useStore()
const [value, setValue] = useState()
```

### Integration
- How this pattern connects to other code
- What events it emits/listens to
- What dependencies it requires
```

## Multishot Examples

### Example 1: Finding Player Component Pattern

```bash
# Search for player files
Glob("**/*player*")

# Read main player component
Read("src/components/Player.tsx")

# Result: Found pattern
# - Functional component with props interface
# - Uses useFrame for animation
# - State managed via Zustand store
# - Three.js mesh for rendering
```

### Example 2: Finding State Store Pattern

```bash
# Find store files
Glob("src/stores/**/*.ts")

# Read game store
Read("src/stores/gameStore.ts")

# Result: Found Zustand pattern
# - create() function with generic type
# - Actions defined inside store
# - Selectors for computed values
# - Typed with TypeScript interface
```

### Example 3: Finding API Call Pattern

```bash
# Search for API calls
Grep("fetch|axios|room\.send", "src/")

# Read service file
Read("src/services/api.ts")

# Result: Found async pattern
# - async/await for API calls
# - Try/catch for error handling
# - Type definitions for responses
# - Loading state management
```

### Example 4: Finding Test Pattern

```bash
# Find test files
Glob("**/*.test.ts")

# Read component test
Read("tests/components/Player.test.tsx")

# Result: Found vitest pattern
# - describe() for test suite
# - test() for individual tests
# - render() from @testing-library
# - expect() for assertions
```

### Example 5: Finding Phaser Scene Pattern

```bash
# Find scene files
Glob("src/scenes/**/*.ts")

# Read game scene
Read("src/scenes/GameScene.ts")

# Result: Found Phaser pattern
# - class extends Phaser.Scene
# - constructor with scene key
# - preload() for assets
# - create() for initialization
# - update() for game loop
```

## Code Patterns

### Research Workflow

```xml
<pattern_discovery_workflow>
1. Parse task for key terms
2. Use Glob to find related files
3. Use Grep to find pattern usage
4. Read 2-3 most relevant files
5. Document patterns found:
   - Component structure
   - State management
   - Import/export patterns
   - Integration points
</pattern_discovery_workflow>
```

### Pattern Categories

**UI Components:**
- Functional components with props
- Hook usage (useState, useEffect, useFrame)
- Styling approach
- Event handlers

**Data Flow:**
- State management (Zustand, Context)
- Props drilling vs store access
- Event emission/handling
- Data transformation

**Architecture:**
- File organization
- Module boundaries
- Export/import patterns
- Dependency injection

## Anti-Patterns

**DON'T:**

- Implement without researching first
- Assume patterns without verifying
- Only look at one example
- Ignore test files
- Copy patterns without understanding them

**DO:**

- Always research before implementing
- Read 2-3 examples of each pattern
- Document patterns with file:line references
- Check tests for usage patterns
- Understand why patterns are used

## Tips

1. **Start with keywords** - Extract from task description
2. **Cast a wide net** - Search multiple related terms
3. **Read similar code** - Even if not exact match
4. **Document everything** - File paths and line numbers
5. **Check tests** - They show real usage
6. **Look for integration** - How code connects
7. **Follow conventions** - Match existing patterns

## See Also

- [dev-research-codebase-exploration](../dev-research-codebase-exploration/SKILL.md) — Glob and Grep search patterns
- [dev-research-gdd-reading](../dev-research-gdd-reading/SKILL.md) — Design document research
- [dev-router](../dev-router/SKILL.md) — Route to appropriate skills
