---
name: codebase-exploration
description: Efficient codebase search using Glob and Grep
---

# Codebase Exploration

Efficiently explore the codebase using Glob and Grep tools.

## Glob Tool

Find files by pattern:

```bash
# Find all TypeScript files
Glob("**/*.ts")

# Find all TSX files
Glob("**/*.tsx")

# Find specific folders
Glob("src/components/**/*.tsx")
Glob("src/hooks/**/*.ts")

# Find files with keyword
Glob("**/*player*")
Glob("**/*physics*")
```

## Grep Tool

Search file contents:

```bash
# Search for specific text
Grep("useFrame", "src/")
Grep("useState", "src/")

# Case-insensitive search
Grep("COLYSEUS", "src/", { ignoreCase: true })

# Search with context
Grep("function.*movement", "src/", { context: 2 })
```

## Search Patterns

### Find Component Definitions
```bash
Grep("function.*Component|const.*=.*=>", "src/components/")
```

### Find State Stores
```bash
Glob("src/stores/**/*.ts")
Grep("create.*Store|zustand", "src/stores/")
```

### Find Type Definitions
```bash
Glob("src/types/**/*.ts")
Grep("interface.*|type.*=", "src/types/")
```

### Find Exports
```bash
Grep("export.*function|export.*const", "src/")
```

## Tips

1. **Start broad, then narrow** - Use Glob first, then Grep
2. **Use specific patterns** - More specific = faster results
3. **Check multiple locations** - Code may be in unexpected places
4. **Read related files** - Found patterns often have related code nearby
