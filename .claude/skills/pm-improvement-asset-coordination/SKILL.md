---
name: pm-improvement-asset-coordination
description: PM asset coordination learnings - parallel development, Vite 6 patterns, memory management
category: pm
user-invocable: false
model: inherit
agent: pm
degrees-of-freedom: medium
---

# PM Asset Coordination Improvement

> "Learn from asset coordination challenges to improve future task assignment."

## When to Use

- After tasks involving asset loading coordination
- When parallel Dev/TA work causes conflicts
- When Vite 6 asset patterns need documentation

---

## Decision Tree for Asset Tasks

```typescript
function assignAssetTask(task) {
  const { category, dependencies } = task;

  // Model loading - sequential for memory management
  if (category === 'model') {
    return { agent: 'developer', execution: 'sequential' };
  }

  // Materials - parallel if models exist
  if (category === 'material' && !hasModelDeps(dependencies)) {
    return { agent: 'techartist', execution: 'parallel' };
  }

  // Textures - parallel safe
  if (category === 'texture') {
    return { agent: 'techartist', execution: 'parallel' };
  }

  // Shaders - sequential compilation
  if (category === 'shader') {
    return { agent: 'techartist', execution: 'sequential' };
  }

  return { agent: 'developer', execution: 'sequential' };
}
```

---

## Decision Framework Matrix

| Scenario | Developer | Tech Artist | Strategy |
|----------|-----------|------------|----------|
| Model + Material | Sequential load | Material prep | Sequential: Model first |
| Multiple models | Sequential + memory | Texture prep | Sequential with budget |
| UI Assets + Models | UI parallel | Model sequential | Parallel UI, sequential models |
| Shader + Texture | Shader first | Texture opt | Sequential: Shader depends on textures |

---

## Anti-Patterns

| ❌ Don't | ✅ Do |
|----------|-------|
| Ignore Vite 6 behavior | Account for Vite 6 patterns |
| Ignore memory implications | Implement memory-aware loading |
| Assign conflicting paths | Validate path overlaps |
| Skip performance tracking | Monitor load times, memory usage |

---

## Memory-Aware Loading

```typescript
function memoryAwareLoading(models, memoryBudget) {
  const loaded = [];
  let currentMemory = 0;

  for (const model of models) {
    const estimated = estimateModelMemory(model);

    if (currentMemory + estimated <= memoryBudget) {
      loaded.push({ model, load: true, memory: estimated });
      currentMemory += estimated;
    } else {
      loaded.push({ model, load: false, deferred: true });
    }
  }

  return loaded;
}
```

---

## Parallel Assignment Validation

```typescript
function validateParallelAssignment(devTasks, taTasks) {
  const pathConflicts = devTasks.some(d =>
    taTasks.some(t => isPathOverlapping(d.path, t.path))
  );

  const resourceConflicts = devTasks.some(d =>
    taTasks.some(t => isSameResource(d.category, t.category))
  );

  return !pathConflicts && !resourceConflicts;
}
```

---

## Performance Monitoring

```typescript
function trackAssetPerformance(metrics) {
  const trends = {
    loadTime: calculateTrend(metrics.map(m => m.loadTime)),
    memoryUsage: calculateTrend(metrics.map(m => m.memory)),
    errorRate: calculateTrend(metrics.map(m => m.errorRate))
  };

  const recommendations = [];
  if (trends.loadTime > 0) recommendations.push('Consider progressive loading');
  if (trends.memoryUsage > 0) recommendations.push('Consider compression');
  if (trends.errorRate > 0) recommendations.push('Improve error handling');

  return { trends, recommendations };
}
```

---

## Vite 6 Considerations

| Directory | Strategy | Use Case |
|-----------|----------|----------|
| `/public/` | Absolute URLs | Static assets, no processing |
| `src/assets/` | Import with `?url` | Processed assets, optimization |
| `/public/assets/` | Absolute URLs | Large models, textures |

---

## Quality Metrics

```typescript
function calculateAssetQuality(metrics) {
  const qualityScore = {
    loading: (metrics.successfulLoads / metrics.total) * 40,
    performance: Math.max(0, 100 - metrics.avgLoadTime / 1000) * 30,
    memory: Math.min(100, metrics.memoryEfficiency) * 20,
    reliability: metrics.errorFreeRate * 10
  };

  const total = Object.values(qualityScore).reduce((a, b) => a + b, 0);
  return { score: total, rating: total > 80 ? 'Excellent' : total > 60 ? 'Good' : 'Improve' };
}
```

---

## References

- [Vite Asset Handling](https://vite.dev/guide/assets) - Official docs
- [R3F Model Loading](https://r3f.docs.pmnd.rs/tutorials/loading-models) - R3F patterns
- [Three.js Performance](https://threejs.org/docs/#manual/en/introduction/Performance) - Optimization
- [BMAD Methodology](https://github.com/bmad-code-org/BMAD-METHOD) - Coordination
