---
name: pm-configuration-asset-coordination
description: Asset coordination best practices for parallel development between Developer and Tech Artist
category: pm
user-invocable: false
model: inherit
agent: pm
degrees-of-freedom: medium
---

# Asset Coordination Best Practices

> "Coordinate parallel asset work without conflicts - manage dependencies, paths, and timing."

## When to Use

- Managing parallel asset tasks between Developer and Tech Artist
- Coordinating model loading with material creation
- Ensuring asset dependencies are properly ordered
- Managing public vs src/assets workflows

---

## Quick Start

### Assignment Matrix

| Priority | Developer | Tech Artist | Strategy |
|----------|-----------|------------|----------|
| High | FBX model loading | Material creation | Sequential - materials need models |
| Medium | Character preview | Shader optimization | Parallel - no conflicts |
| Low | Asset path setup | Texture optimization | Sequential - path first |

### Coordination Flow

```typescript
function assignAssetTasks(tasks) {
  const sorted = tasks.sort((a, b) => {
    if (a.dependencies?.includes(b.id)) return 1;
    if (b.dependencies?.includes(a.id)) return -1;
    return a.priority.localeCompare(b.priority);
  });

  const devTasks = sorted.filter(t => t.agent === 'developer');
  const taTasks = sorted.filter(t => t.agent === 'techartist');

  const conflicts = checkConflicts(devTasks, taTasks);
  return { developerTasks, techArtistTasks, conflicts };
}
```

---

## Anti-Patterns

| ❌ Don't | ✅ Do |
|----------|-------|
| Assign conflicting paths | Validate path overlaps first |
| Ignore memory implications | Implement memory-aware loading |
| Load all assets at once | Implement batching/priority |
| Skip dependency checks | Verify all deps satisfied |

**Example - Sequential for Dependencies:**

```typescript
// ✅ Good - Materials wait for models
const sequentialTasks = [
  { id: 'feat-001', category: 'model', agent: 'developer' },
  { id: 'vis-001', category: 'material', agent: 'techartist', dependencies: ['feat-001'] }
];
```

---

## Parallel Assignment Rules

| Developer Category | Tech Artist Category | Safe? |
|-------------------|---------------------|-------|
| `model` (src/components/Character) | `material` (src/components/Materials) | ✅ Yes |
| `shader` (src/shaders/) | `texture` (src/textures/) | ✅ Yes |
| `model` (src/components/) | `material` (src/components/) | ❌ No - same directory |

---

## Conflict Detection

```typescript
function checkConflicts(devTasks, taTasks) {
  const conflicts = [];

  // Check path overlaps
  for (const dev of devTasks) {
    for (const ta of taTasks) {
      if (isPathOverlapping(dev.path, ta.path)) {
        conflicts.push({ type: 'path_overlap', dev, ta });
      }
    }
  }

  // Check circular deps
  for (const dev of devTasks) {
    for (const ta of taTasks) {
      if (dev.dependencies?.includes(ta.id) && ta.dependencies?.includes(dev.id)) {
        conflicts.push({ type: 'circular_dependency', dev, ta });
      }
    }
  }

  return conflicts;
}
```

---

## Resource Coordination

```typescript
function coordinateResources(tasks, budget) {
  const sorted = tasks.sort((a, b) => b.priority.localeCompare(a.priority));

  let currentMemory = 0;
  const scheduled = [];

  for (const task of sorted) {
    const resources = estimateTaskResources(task);

    if (currentMemory + resources.memory <= budget.memory) {
      scheduled.push(task);
      currentMemory += resources.memory;
    } else {
      scheduled.push({ ...task, scheduling: 'deferred' });
    }
  }

  return scheduled;
}
```

---

## Status Tracking

```typescript
function trackAssetWorkflow(statuses) {
  return {
    pending: statuses.filter(s => s.status === 'pending').length,
    inProgress: statuses.filter(s => s.status === 'in_progress').length,
    completed: statuses.filter(s => s.status === 'completed').length,
    progress: (statuses.filter(s => s.status === 'completed').length / statuses.length) * 100
  };
}
```

---

## Dependency Resolution

```typescript
function resolveDependencies(tasks) {
  const resolved = [];
  const unresolved = [];

  while (tasks.length > 0) {
    const ready = tasks.find(t =>
      !t.dependencies?.some(dep => !resolved.includes(dep))
    );

    if (ready) {
      resolved.push(ready.id);
      tasks = tasks.filter(t => t.id !== ready.id);
    } else {
      // Circular dep - skip
      unresolved.push(tasks[0].id);
      tasks = tasks.slice(1);
    }
  }

  return { resolved, unresolved };
}
```

---

## References

- [Vite Asset Documentation](https://vite.dev/guide/assets) - Official asset handling
- [R3F Model Loading](https://r3f.docs.pmnd.rs/tutorials/loading-models) - Model loading patterns
- [Three.js Performance](https://threejs.org/docs/#manual/en/introduction/Performance) - Optimization
