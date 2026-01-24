---
name: asset-coordination-best-practices
description: PM coordination strategies for asset-related development in Vite 6 projects
category: coordination
---

# PM Coordination for Asset Development

## When to Use

- Coordinating cross-agent asset development
- Managing asset optimization decisions
- Resolving technical vs. design trade-offs
- Planning asset development workflows
- Quality assurance for asset integration

## Quick Start

```markdown
## Asset Coordination Checklist

### Before Asset Development Task
- [ ] Define asset quality requirements
- [ ] Establish performance targets
- [ ] Set up asset testing criteria
- [ ] Coordinate between Developer, Tech Artist, and Game Designer
- [ ] Prepare Vite 6 configuration review

### During Asset Development
- [ ] Monitor build performance
- [ ] Track asset loading times
- [ ] Review asset integration progress
- [ ] Address technical blockers promptly
- [ ] Maintain asset consistency

### After Asset Development
- [ ] Validate asset performance goals
- [ ] Verify visual/audio quality standards
- [ ] Check cross-browser compatibility
- [ ] Update asset documentation
- [ ] Plan future asset improvements
```

## Cross-Agent Coordination Framework

### 1. Asset Development Workflow

```markdown
**Standard Asset Development Process:**

1. **Planning Phase** (PM + Game Designer)
   - Define asset requirements
   - Set quality vs. performance targets
   - Establish acceptance criteria

2. **Creation Phase** (Tech Artist)
   - Create/procure assets
   - Apply optimization techniques
   - Prepare for integration

3. **Integration Phase** (Developer)
   - Implement asset loading
   - Add error handling
   - Optimize performance

4. **Validation Phase** (QA)
   - Test functionality
   - Verify performance
   - Check quality standards

5. **Review Phase** (PM + All)
   - Evaluate success
   - Identify improvements
   - Plan next steps
```

### 2. Quality Gate System

```markdown
**Asset Quality Gates:**

| Gate | Criteria | Responsible Party | Action if Failed |
|------|----------|------------------|------------------|
| Technical Quality | Performance targets, build success | Developer + QA | Return to Developer |
| Visual Quality | Visual fidelity, design consistency | Tech Artist + Game Designer | Return to Tech Artist |
| Integration Quality | Cross-system compatibility | Developer | Fix implementation |
| User Experience | Playability, feedback clarity | Game Designer + QA | Rework design |
| Performance | Frame rates, memory usage | QA + Developer | Optimize assets |

**Quality Gate Process:**
1. Define clear acceptance criteria for each gate
2. Run automated tests first
3. Conduct manual review by appropriate party
4. Document any failures and required fixes
5. Only proceed when all gates pass
```

### 3. Communication Protocol

```markdown
**Asset Development Communication Patterns:**

**Status Updates:**
- Daily stand-ups for active asset tasks
- Performance metrics tracking
- Quality milestone announcements
- Blocker escalation procedures

**Decision Meetings:**
- Quality vs. performance trade-offs
- Asset optimization direction
- Resource allocation
- Timeline adjustments

**Documentation Standards:**
- Asset requirement documents
- Technical specifications
- Performance baselines
- Quality test results

**Meeting Templates:**
```markdown
## Asset Development Meeting Agenda

1. Review current asset development status
   - [ ] Asset progress tracking
   - [ ] Performance metrics
   - [ ] Quality indicators

2. Address technical challenges
   - [ ] Build performance issues
   - [ ] Asset loading problems
   - [ ] Compatibility concerns

3. Make quality decisions
   - [ ] Visual vs. performance balance
   - [ ] Optimization priority
   - [ ] Resource allocation

4. Plan next steps
   - [ ] Action items
   - [ ] Timeline adjustments
   - [ ] Resource needs
```
```

## Technical Coordination Strategies

### 1. Vite 6 Configuration Management

```markdown
**Configuration Review Checklist:**

| Configuration Area | Review Points | Responsibility |
|-------------------|---------------|----------------|
| optimizeDeps | Wildcard patterns, excluded packages | Developer |
| assetsInclude | Asset pattern matching | Tech Artist |
| build | Asset optimization settings | Developer |
| server | Development server settings | Developer |
| plugins | Custom asset handling | All agents |

**Configuration Validation Process:**
1. Developer provides configuration changes
2. Tech Artist reviews asset patterns
3. QA tests build performance
4. PM coordinates final approval
5. Configuration is documented and committed

**Common Configuration Issues:**
```typescript
// ❌ Incorrect wildcard pattern
optimizeDeps: {
  exclude: ['**/*.fbx'] // Vite 6 doesn't support double wildcard
}

// ✅ Correct pattern
optimizeDeps: {
  exclude: ['*.fbx'] // Single wildcard only
}

// ❌ Missing asset patterns
// assetsInclude should include all asset types

// ✅ Comprehensive asset patterns
assetsInclude: [
  '**/*.fbx',
  '**/*.glb',
  '**/*.gltf',
  '**/*.png',
  '**/*.jpg',
  '**/*.ogg',
  '**/*.mp3'
]
```
```

### 2. Performance Monitoring Coordination

```markdown
**Performance Tracking System:**

**Metrics to Monitor:**
- Asset loading times
- Memory usage patterns
- Frame rate stability
- Build performance
- Network request efficiency

**Monitoring Responsibilities:**
- **Developer**: Technical metrics, build performance
- **Tech Artist**: Visual quality, optimization results
- **QA**: User experience, compatibility
- **PM**: Overall coordination, trend analysis

**Performance Alert System:**
```typescript
// Performance thresholds
const performanceThresholds = {
  assetLoadTime: 2000, // 2 seconds max
  memoryUsage: 500 * 1024 * 1024, // 500MB max
  frameRate: 30, // 30 FPS minimum
  buildTime: 30000 // 30 seconds max
}

// Alert levels
enum AlertLevel {
  INFO = 'info',
  WARNING = 'warning',
  CRITICAL = 'critical'
}

// Performance coordinator class
class PerformanceCoordinator {
  private metrics: Map<string, number> = new Map()
  private alerts: Map<string, AlertLevel> = new Map()

  updateMetric(name: string, value: number, threshold: number) {
    this.metrics.set(name, value)

    if (value > threshold) {
      const level = value > threshold * 1.5 ? AlertLevel.CRITICAL : AlertLevel.WARNING
      this.alerts.set(name, level)
      this.notifyStakeholders(name, value, level)
    }
  }

  private notifyStakeholders(metric: string, value: number, level: AlertLevel) {
    // PM coordinates appropriate response
    if (level === AlertLevel.CRITICAL) {
      // Immediate action required
      this.escalateIssue(metric)
    } else {
      // Monitor and plan fix
      this.scheduleReview(metric)
    }
  }
}
```
```

### 3. Quality Assurance Coordination

```markdown
**QA-Development Integration:**

**Testing Coordination:**
- **Before Development**: Define test criteria
- **During Development**: Continuous testing
- **Before Deployment**: Full validation suite
- **Post-Deployment**: Performance monitoring

**Test Categories:**
1. **Functional Tests**
   - Asset loading without errors
   - Animation playback
   - Audio functionality

2. **Performance Tests**
   - Load time verification
   - Memory usage patterns
   - Frame rate consistency

3. **Visual Tests**
   - Quality standards compliance
   - Cross-platform consistency
   - Animation smoothness

4. **Compatibility Tests**
   - Browser compatibility
   - Device capability matching
   - Network condition tolerance

**QA-Developer Handoff:**
```typescript
// Test result coordination
interface TestResult {
  asset: string
  category: 'functional' | 'performance' | 'visual' | 'compatibility'
  passed: boolean
  metrics?: Record<string, number>
  issues?: string[]
}

class QAIntegrationCoordinator {
  private testResults: TestResult[] = []

  async runFullTestSuite(assets: string[]): Promise<TestResult[]> {
    const results: TestResult[] = []

    for (const asset of assets) {
      // Run all test categories
      const functional = await this.testFunctional(asset)
      const performance = await this.testPerformance(asset)
      const visual = await this.testVisual(asset)
      const compatibility = await this.testCompatibility(asset)

      results.push([functional, performance, visual, compatibility])
    }

    this.testResults = results
    return results
  }

  generateReport(): AssetQualityReport {
    const summary = this.summarizeResults()
    const recommendations = this.generateRecommendations()

    return {
      summary,
      recommendations,
      nextSteps: this.planNextSteps()
    }
  }
}
```
```

## Decision Framework

### 1. Asset Optimization Decisions

```markdown
**Decision Matrix for Asset Optimization:**

| Factor | High Priority | Medium Priority | Low Priority |
|--------|---------------|-----------------|---------------|
| Visual Impact | Keep detail, optimize elsewhere | Balance detail with performance | Reduce detail |
| Usage Frequency | Optimize heavily | Moderate optimization | Minimal optimization |
| Performance Impact | Critical path optimization | Standard optimization | Delay optimization |
| Player Visibility | Always visible | Occasionally visible | Rarely visible |

**Decision Process:**
1. Gather performance data
2. Assess visual importance
3. Consider usage patterns
4. Evaluate technical constraints
5. Make informed decision

**Decision Documentation:**
```typescript
interface AssetDecision {
  asset: string
  decision: 'optimize' | 'reduce' | 'maintain' | 'stream'
  reasoning: string
  performanceImpact: {
    before: number
    after: number
    improvement: number
  }
  visualImpact: {
    before: number
    after: number
    quality: 'maintained' | 'reduced' | 'streamed'
  }
  stakeholders: {
    developer: string
    techArtist: string
    gameDesigner: string
    qa: string
  }
  timeline: {
    planned: Date
    completed?: Date
    reviewed?: Date
  }
}
```
```

### 2. Resource Allocation

```markdown
**Resource Allocation Strategy:**

**Resource Types:**
- Development time
- Tech Artist time
- QA time
- Build infrastructure
- Testing resources

**Allocation Criteria:**
- Asset importance to gameplay
- Technical complexity
- Quality requirements
- Timeline constraints
- Resource availability

**Priority System:**
```typescript
enum AssetPriority {
  CRITICAL = 1,
  HIGH = 2,
  MEDIUM = 3,
  LOW = 4
}

class ResourceAllocator {
  private resourcePool: Record<string, number> = {
    developer: 40, // hours per week
    techArtist: 30,
    qa: 20
  }

  private assetPriorities: Map<string, AssetPriority> = new Map()

  allocateResources(assets: Asset[]): ResourceAllocation[] {
    const allocation: ResourceAllocation[] = []

    // Sort by priority
    const sortedAssets = assets.sort((a, b) =>
      this.assetPriorities.get(b.id) - this.assetPriorities.get(a.id)
    )

    for (const asset of sortedAssets) {
      const hoursNeeded = this.calculateHoursNeeded(asset)
      const availableResources = this.getAvailableResources()

      if (this.canAllocate(hoursNeeded, availableResources)) {
        allocation.push({
          asset: asset.id,
          hours: hoursNeeded,
          developer: Math.min(hoursNeeded.developer, availableResources.developer),
          techArtist: Math.min(hoursNeeded.techArtist, availableResources.techArtist),
          qa: Math.min(hoursNeeded.qa, availableResources.qa)
        })

        this.updateResourcePool(allocation[allocation.length - 1])
      } else {
        // Escalate for additional resources
        this.escalateResourceRequest(asset, hoursNeeded)
      }
    }

    return allocation
  }
}
```
```

## Documentation and Knowledge Management

### 1. Asset Documentation System

```markdown
**Asset Documentation Template:**

**Asset Metadata:**
- Name and identifier
- Type (character, environment, etc.)
- Size and complexity
- Performance characteristics
- Quality requirements

**Technical Documentation:**
- File formats and specifications
- Loading requirements
- Dependencies
- Optimization techniques used
- Known issues

**Design Documentation:**
- Purpose in game design
- Visual style guidelines
- Animation requirements
- Audio specifications
- User experience goals

**Performance Data:**
- Loading times
- Memory usage
- Impact on frame rate
- Optimization results
- Testing results

**Knowledge Base Structure:**
```typescript
interface AssetDocumentation {
  id: string
  name: string
  version: string
  metadata: {
    type: string
    size: number
    format: string
    priority: AssetPriority
  }
  technical: {
    loadingRequirements: string[]
    dependencies: string[]
    optimization: string[]
    troubleshooting: string[]
  }
  design: {
    purpose: string
    style: string
    animations: string[]
    audio: {
      type: string
      volume: number
      spatial: boolean
    }
  }
  performance: {
    loadTime: number
    memory: number
    frameRate: number
    optimized: boolean
    testResults: TestResult[]
  }
}
```
```

### 2. Knowledge Sharing Protocol

```markdown
**Internal Knowledge Sharing:**

**Regular Updates:**
- Daily asset development summaries
- Performance metric reports
- Quality assurance results
- Technical issue resolutions

**Documentation Updates:**
- New asset specifications
- Updated performance guidelines
- Optimization techniques
- Testing procedures

**Training Materials:**
- Vite 6 configuration guides
- Asset optimization best practices
- Performance testing methods
- Quality assurance procedures

**Knowledge Repository:**
```typescript
class KnowledgeManager {
  private documentation: Map<string, AssetDocumentation> = new Map()
  private metrics: Map<string, PerformanceMetric> = new Map()
  private issues: Map<string, TechnicalIssue> = new Map()

  addAssetDocumentation(doc: AssetDocumentation) {
    this.documentation.set(doc.id, doc)
    this.notifyStakeholders('newAsset', doc)
  }

  updatePerformanceMetrics(asset: string, metrics: PerformanceMetric) {
    this.metrics.set(asset, metrics)
    this.notifyStakeholders('performanceUpdate', { asset, metrics })
  }

  addTechnicalIssue(issue: TechnicalIssue) {
    this.issues.set(issue.id, issue)
    this.notifyStakeholders('technicalIssue', issue)
  }

  generateWeeklyReport(): WeeklyReport {
    return {
      assetsAdded: Array.from(this.documentation.keys()),
      performanceMetrics: Array.from(this.metrics.values()),
      issuesResolved: Array.from(this.issues.values()).filter(i => i.resolved),
      recommendations: this.generateRecommendations()
    }
  }
}
```
```

## Anti-Patterns

### 1. Poor Communication
**❌ DON'T:**
```markdown
- Working in isolation without updates
- Not sharing performance concerns
- Delaying bad news
- Not documenting decisions
```

**✅ DO:**
```markdown
- Regular status updates to all stakeholders
- Immediate sharing of blockers
- Transparent communication of issues
- Comprehensive documentation of decisions
```

### 2. Inconsistent Quality Standards
**❌ DON'T:**
```markdown
- Different standards for different assets
- Ignoring technical constraints
- Prioritizing one aspect over others
- Not validating against requirements
```

**✅ DO:**
```markdown
- Consistent quality standards across all assets
- Balanced approach to technical and design requirements
- Data-driven decision making
- Comprehensive validation process
```

### 3. Reactive Coordination
**❌ DON'T:**
```markdown
- Waiting for problems to arise
- Not planning for technical constraints
- Ignoring performance concerns
- Not testing early and often
```

**✅ DO:**
```markdown
- Proactive planning and risk assessment
- Early testing and feedback
- Continuous performance monitoring
- Anticipating and preventing issues
```

## Reference

- [Project Management Institute (PMI)](https://www.pmi.org/)
- [Agile Project Management Principles](https://www.agilealliance.org/)
- [Technical Project Management Best Practices](https://www.atlassian.com/agile/project-management)
- [Cross-Functional Team Coordination](https://www.scrum.org/)