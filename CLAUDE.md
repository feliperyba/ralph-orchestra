# Ralph Orchestra - Claude Documentation

## Overview

**Ralph Orchestra** is a multi-agent autonomous development framework that coordinates multiple Claude CLI agents to work together on software development tasks.

### Key Features

- **Multi-Agent Coordination** - PM, Developer, and QA agents with modular skills
- **Four Orchestration Modes** - Event-driven, Sequential, Polling, or HITL
- **Watchdog Process** - Never-exit orchestrator that manages agent lifecycle
- **Message-Based Communication** - File-based messages for agent coordination
- **Scale-Adaptive Planning** - PM adjusts approach based on PRD task count (0-4)
- **Skill Improvement** - Agents research and propose skill updates during retrospectives

### Quick Start

```powershell
# Event-driven mode (recommended - parallel with message queues)
.\.claude\scripts\ralph-event-session.ps1

# Sequential mode (token-efficient - one agent at a time)
.\.claude\scripts\ralph-single-session.ps1

# Polling mode (legacy - parallel with 30s polling)
.\.claude\scripts\ralph-multi-session.ps1

# HITL mode (learn the flow before going AFK)
/ralph-hitl
```

### Documentation

| Document                                               | Purpose                           |
| ------------------------------------------------------ | --------------------------------- |
| [README.md](README.md)                                 | Full project documentation        |
| [.claude/scripts/README.md](.claude/scripts/README.md) | Script reference                  |
| [agents/\*/AGENT.md](agents/)                          | Per-agent behavior instructions   |
| [agents/\*/skills/](agents/)                           | Modular skills (YAML frontmatter) |
| [.claude/skills/](/.claude/skills/)                    | Orchestration skills & routers    |

---

## Project Overview

This is a Three.js game inspired by Bruno Simon's portfolio (folio-2025), adapted to use React Three Fiber with TypeScript and Vite.

**Tech Stack:**

- **Three.js** - 3D rendering engine
- **React Three Fiber** (@react-three/fiber) - React renderer for Three.js
- **@react-three/drei** - Helper components and abstractions
- **@react-three/rapier** - Physics integration
- **Colyseus.js** - Multiplayer SDK Framework
- **TypeScript** - Type-safe development
- **Vite** - Fast build tool and dev server
- **Zustand** - State management
- **Leva** - Debug GUI controls

**Agent System (Modular Skills):**

- **PM Agent** - [skills/](agents/pm/skills/) - Task selection, scale-adaptive planning, retrospectives, skill improvement
- **Developer Agent** - [skills/](agents/developer/skills/) - R3F fundamentals, materials, physics, performance, feedback loops
- **QA Agent** - [skills/](agents/qa/skills/) - Validation workflow, browser testing, bug reporting

## Project Structure

```
src/
├── components/      # React components
│   ├── game/       # Game-specific components
│   ├── shaders/    # Custom shader materials
│   ├── effects/    # Post-processing effects
│   └── utils/      # Utility components
├── store/          # Zustand stores
├── hooks/          # Custom React hooks
├── utils/          # Utility functions
└── styles/         # CSS styles
```

## Development Workflow

### Start Development Server

```bash
npm run dev
```

Opens at `http://localhost:3000`

### Build for Production

```bash
npm run build
```

### Run Tests

```bash
npm run test          # Unit tests with Vitest
npm run test:e2e      # E2E tests with Playwright
```

### Lint and Format

```bash
npm run lint          # Check code quality
npm run lint:fix      # Fix lint issues
npm run format        # Format code with Prettier
```

## Key Architecture Patterns

### Game Loop with useFrame

Unlike vanilla Three.js with `requestAnimationFrame`, R3F uses the `useFrame` hook:

```tsx
import { useFrame } from '@react-three/fiber';

function MyComponent() {
  useFrame((state, delta) => {
    // state.clock - elapsed time
    // delta - time since last frame
    // Runs at monitor refresh rate (typically 60Hz)
  });
}
```

### ECS System using Tick-Knock

### State Management with Zustand

```tsx
import { useGameStore } from '@/store/gameStore';

function MyComponent() {
  const { phase, setPhase, playerPosition } = useGameStore();
}
```

### Debug Controls with Leva

```tsx
import { useControls } from 'leva';

const debug = useControls({
  gravity: { value: -9.8, min: -20, max: 0 },
  speed: { value: 5, min: 0, max: 20 },
});
```

## Common Tasks

### Adding a New Game Component

1. Create component in `src/components/game/`
2. Use `useFrame` for animation
3. Use `useGameStore` for state access
4. Add to `Experience.tsx`

### Creating a Custom Shader

1. Create GLSL file in `src/components/shaders/chunks/`
2. Create shader component in `src/components/shaders/`
3. Use `<shaderMaterial>` from R3F

### Adding Physics

1. Create physics body with `@react-three/rapier`
2. Use `<Physics>` provider in scene
3. Use `<RigidBody>` and collider components
4. See [`agents/developer/skills/r3f-physics.md`](agents/developer/skills/r3f-physics.md) for patterns

## Performance Guidelines

- Use instancing for repeated objects (trees, grass)
- Limit shadow map resolution
- Use `dpr={[1, 2]}` for pixel ratio limiting
- Enable `powerPreference: 'high-performance'` in Canvas
- Use Suspense for async asset loading

## Asset Optimization

- **Models**: Use GLTF/GLB with Draco compression
- **Textures**: Use WebP or basis universal
- **Audio**: Use compressed formats (MP3/OGG)
- Place all assets in `public/assets/`

## MCP Server Configuration

Each agent has specific MCP servers configured:

- **Developer Agent** - GitHub, filesystem, web-search, brave-search
- **QA Agent** - Playwright, filesystem, GitHub
- **PM Agent** - GitHub, web-search, filesystem

See [`.claude/settings.{agent}.json`](.claude/) for details.

---

## Ralph Wiggum Autonomous Development

Ralph Wiggum is a plugin that enables autonomous AI development loops with multi-agent coordination. It allows PM, Developer, and QA agents to work together without human intervention across multiple terminal sessions.

### Quick Start

```powershell
# Option 1: Event-Driven (Recommended)
.\.claude\scripts\ralph-event-session.ps1

# Option 2: Sequential (Token-Efficient)
.\.claude\scripts\ralph-single-session.ps1

# Option 3: Manual Terminal Setup (Polling Mode)
# Terminal 1: PM Agent (Coordinator)
/ralph-coordinator

# Terminal 2: Developer Agent (Worker)
/ralph-worker --agent developer

# Terminal 3: QA Agent (Worker)
/ralph-worker --agent qa
```

### Commands

| Command                     | Purpose                                      |
| --------------------------- | -------------------------------------------- |
| `/ralph-coordinator`        | Start PM agent in polling mode               |
| `/ralph-coordinator-single` | Start PM agent in sequential mode            |
| `/ralph-worker --agent X`   | Start worker agent (developer/qa) in polling |
| `/ralph-worker-single`      | Start worker agent in sequential mode        |
| `/ralph-hitl`               | Single iteration mode for learning           |
| `/cancel-ralph`             | Cancel active loop                           |

### How Ralph Works

1. **PM Agent** reviews `prd.json`, applies scale-adaptive planning (0-4), and assigns tasks
2. **Developer Agent** implements features using R3F skills and runs feedback loops
3. **QA Agent** validates with tests, browser checks, and structured bug reports
4. **PM Agent** updates PRD status, runs retrospective, proposes skill improvements
5. Progress tracked in `progress.txt` and `.claude/session/` files
6. Each iteration commits work
7. Loop continues until all PRD items have `passes: true`

### Session Files

| File                                     | Purpose                                  |
| ---------------------------------------- | ---------------------------------------- |
| `prd.json`                               | Project requirements with `passes` field |
| `progress.txt`                           | Session progress log                     |
| `.claude/session/coordinator-state.json` | Shared coordination state                |
| `.claude/session/current-task.json`      | Active task details                      |
| `.claude/session/handoff-signal.json`    | Agent switching signals (sequential)     |
| `.claude/session/messages/`              | Message queues (event-driven)            |

### Multi-Session Architecture

**Event-Driven Mode (Recommended):**

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WATCHDOG (Message Broker)                         │
│              (Routes messages, monitors health)                      │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │   PM    │◄──────────►│Developer│◄──────────►│   QA    │
   │ (inbox) │            │ (inbox) │            │ (inbox) │
   └─────────┘            └─────────┘            └─────────┘
```

**Sequential Mode (Token-Efficient):**

```
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │   PM    │ ─handoff─▶ │Developer│ ─handoff─▶ │   QA    │
   │  Agent  │            │  Agent  │            │  Agent  │
   └─────────┘            └─────────┘            └─────────┘
        ▲                                              │
        └──────────────────────────────────────────────┘
                        (one at a time)
```

### Best Practices

1. **Start with HITL mode** - Use `/ralph-hitl` to learn behavior before going AFK
2. **Use max-iterations** - Always set a safety limit (default: 50)
3. **Define clear scope** - PRD items with explicit acceptance criteria
4. **Track progress** - `progress.txt` logs all completed work
5. **Review commits** - Check git log after loop completes
6. **Small tasks** - Keep PRD items focused for better quality

### Quality Standards

All Ralph work follows production standards:

- No `any` types without justification
- Test coverage > 80% for new code
- Documentation for complex logic
- All feedback loops must pass (type-check, lint, test, build)

### Ralph Documentation

**Orchestration Skills:**

- [`.claude/skills/ralph-core.md`](.claude/skills/ralph-core.md) - Core orchestration concepts
- [`.claude/skills/ralph-router.md`](.claude/skills/ralph-router.md) - Routes to agent skills
- [`.claude/skills/ralph-handoff.md`](.claude/skills/ralph-handoff.md) - Handoff protocol
- [`.claude/skills/ralph-event-protocol.md`](.claude/skills/ralph-event-protocol.md) - Event-driven messaging

**Agent Behavior:**

- [`agents/pm/AGENT.md`](agents/pm/AGENT.md) - PM instructions + [skills/](agents/pm/skills/)
- [`agents/developer/AGENT.md`](agents/developer/AGENT.md) - Developer instructions + [skills/](agents/developer/skills/)
- [`agents/qa/AGENT.md`](agents/qa/AGENT.md) - QA instructions + [skills/](agents/qa/skills/)

### Example PRD Item

```json
{
  "id": "feat-001",
  "category": "architectural",
  "priority": "high",
  "title": "Vehicle Physics Implementation",
  "acceptanceCriteria": ["Vehicle spawns at origin", "WASD controls work", "Physics runs at 60fps"],
  "passes": false,
  "agent": "developer"
}
```

### See Also

- [README.md](README.md) - Full project documentation with orchestration modes
- [.claude/scripts/README.md](.claude/scripts/README.md) - Script reference and mode selection guide
- [Claude CLI Documentation](https://docs.anthropic.com/en/docs/claude-cli)

### Ralph Troubleshooting

#### Agent stops polling after a few actions

**Symptoms**: Worker or coordinator stops working after completing N tasks.

**Solutions**:

1. Check that skill files have proper YAML frontmatter with `category` field
2. Verify `.claude/hooks/stop-hook.ps1` returns exit code 42
3. Check terminal for any error messages
4. For sequential mode, verify handoff signals are being written
5. For event-driven mode, check message queue in `.claude/session/messages/`

#### Context window overflow

**Symptoms**: Agent becomes slow, forgets previous context, or gives inconsistent responses.

**Solutions**:

1. The agent should automatically detect and reset context at ~70% capacity
2. Manual reset: Output `<promise>CONTEXT_RESET</promise>` in the agent's session
3. Check `.claude/session/context-reset-count.txt` to see how many resets occurred
4. Reset count is tracked automatically and displayed in hook output

#### Session files not found

**Symptoms**: "Waiting for coordinator..." or "Session file not found" errors.

**Solutions**:

1. Use launcher scripts (`ralph-event-session.ps1`, `ralph-single-session.ps1`) which auto-create session
2. For manual setup, ensure `.claude/session/` directory exists
3. For event-driven mode, ensure `.claude/session/messages/` subdirectories exist
4. Check file permissions on the session directory

#### MCP filesystem path errors

**Symptoms**: "Path not found" or filesystem MCP errors.

**Solutions**:

1. Check `.claude/settings.{agent}.json` has correct project paths
2. Paths should point to current project, not old directories
3. Update paths if project location changed

---

## Troubleshooting

### Scene not rendering

- Check browser console for errors
- Verify Canvas has dimensions
- Check if Suspense boundary is needed

### Performance issues

- Enable Leva debug panel
- Check FPS counter
- Use Chrome DevTools Performance tab

### TypeScript errors

- Run `npm run type-check`
- Check `tsconfig.json` paths are correct
- Verify `three` types are installed

## Resources

### R3F & Three.js

- [R3F Documentation](https://r3f.docs.pmnd.rs/)
- [Drei Helpers](https://drei.docs.pmnd.rs/)
- [Three.js Docs](https://threejs.org/docs/)
- [Rapier Physics](https://rapier.rs/)

### Agent Skills Reference

- [R3F Fundamentals](agents/developer/skills/r3f-fundamentals.md)
- [R3F Performance](agents/developer/skills/r3f-performance.md)
- [R3F Physics](agents/developer/skills/r3f-physics.md)
- [Validation Workflow](agents/qa/skills/validation-workflow.md)
- [Scale-Adaptive Planning](agents/pm/skills/scale-adaptive.md)

### Inspiration

- [Bruno Simon's Portfolio](https://bruno-simon.com/)
- [Three.js Journey](https://threejs-journey.com/)
- [folio-2025 repository](https://github.com/brunosimon/folio-2025)
