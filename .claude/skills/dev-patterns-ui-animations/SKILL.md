---
name: ui-animations
description: Game UI and HUD animation patterns with Framer Motion. Use when animating HUD elements.
category: patterns
keywords: [ui, animation, hud, framer-motion, react]
---

# Game UI Animations

> "Smooth, responsive UI animations provide critical game feel feedback."

## When to Use

Use when:
- Creating HUD elements (kill feed, score updates, notifications)
- Adding entry/exit animations for UI panels
- Implementing smooth value transitions (timer countdown, health bars)

## Quick Start

```tsx
import { motion, AnimatePresence } from 'motion/react';

// Kill feed entry animation
function KillFeedEntry({ kill, onExit }) {
  return (
    <AnimatePresence>
      <motion.div
        initial={{ x: 100, opacity: 0 }}
        animate={{ x: 0, opacity: 1 }}
        exit={{ x: -100, opacity: 0 }}
        transition={{ duration: 0.3, ease: 'easeOut' }}
        onAnimationComplete={onExit}
      >
        {kill.killer} splatted {kill.victim}
      </motion.div>
    </AnimatePresence>
  );
}
```

## Decision Framework

| Need | Use |
|------|-----|
| Simple entry/exit animations | CSS transitions with Tailwind classes |
| Complex choreography | Motion (Framer Motion) variants |
| Continuous value updates | CSS transforms with requestAnimationFrame |
| 3D UI attached to camera | R3F Html component + CSS animations |
| High-frequency updates | Transform only (no layout triggers) |

## CSS-Only Animations (Fastest)

```tsx
function KillFeedItem({ killer, victim }) {
  return (
    <div className="kill-feed-item animate-slide-in">
      <span className="killer-name">{killer}</span>
      <span className="skull-icon">💀</span>
      <span className="victim-name">{victim}</span>
    </div>
  );
}

/* CSS */
@keyframes slideIn {
  from {
    transform: translateX(100%);
    opacity: 0;
  }
  to {
    transform: translateX(0);
    opacity: 1;
  }
}

@keyframes fadeOut {
  from { opacity: 1; }
  to { opacity: 0; }
}

.kill-feed-item {
  animation: slideIn 0.3s ease-out;
  will-change: transform, opacity;
}
```

## Framer Motion for Complex UI

```tsx
function KillFeed({ kills }) {
  return (
    <div className="kill-feed">
      <AnimatePresence mode="popLayout">
        {kills.map((kill) => (
          <motion.div
            key={kill.id}
            layout
            initial={{ x: 100, opacity: 0, scale: 0.8 }}
            animate={{ x: 0, opacity: 1, scale: 1 }}
            exit={{ x: -100, opacity: 0, scale: 0.8 }}
            transition={{
              type: 'spring',
              stiffness: 300,
              damping: 25
            }}
            className="kill-entry"
          >
            <span className="killer">{kill.killer}</span>
            <span>⚔️</span>
            <span className="victim">{kill.victim}</span>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
```

## Timer Animation

```tsx
function MatchTimer({ duration, remaining }) {
  const progress = remaining / duration;

  return (
    <div className="match-timer">
      <motion.div
        className="timer-bar"
        style={{
          scaleX: progress,
          transformOrigin: 'left'
        }}
        transition={{ ease: 'linear', duration: 1 }}
      />
      <span className="timer-text">
        {Math.floor(remaining / 60)}:{(remaining % 60).toString().padStart(2, '0')}
      </span>
    </div>
  );
}
```

## Health/Ink Bar with Color Transition

```tsx
function InkTankIndicator({ current, max }) {
  const percentage = (current / max) * 100;

  // Color transitions from blue (full) to red (low)
  const color = percentage > 50
    ? '#3b82f6' // blue
    : percentage > 25
    ? '#f59e0b' // orange
    : '#ef4444'; // red

  return (
    <div className="ink-tank">
      <motion.div
        className="ink-level"
        style={{ backgroundColor: color }}
        animate={{ width: `${percentage}%` }}
        transition={{ type: 'spring', stiffness: 200, damping: 20 }}
      />
      <span className="ink-text">{Math.floor(current)} / {max}</span>
    </div>
  );
}
```

## Common Mistakes

| ❌ Wrong | ✅ Right |
|----------|----------|
| Animating layout properties (width, height) | Use transform: scaleX/scaleX |
| Not using will-change | Add for GPU acceleration |
| Overusing spring animations | Use for UI, not game logic |
| Animating during high FPS | Consider throttling |

## Reference

- [mobile-haptics.md](./mobile-haptics.md) - Haptic feedback
