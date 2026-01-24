---
name: browser-testing
description: Playwright patterns for browser validation
category: validation
keywords: [browser, playwright, test, visual]
---

# Browser Testing

Use Playwright MCP for browser validation of visual/gameplay changes.

## When to Use Browser Testing

- Visual changes (UI, materials, shaders)
- Gameplay mechanics (movement, physics)
- User interactions (input, controls)
- Before sending to QA

## Testing Process

### 1. Start Dev Server

```bash
npm run dev:all:sh
```

Server runs on http://localhost:3000

### 2. Navigate to Application

```
Navigate to http://localhost:3000
```

### 3. Test the Feature

- Exercise the implemented functionality
- Check for visual issues
- Verify behavior matches requirements

### 4. Check Console

- No errors (red text)
- No warnings (yellow text)
- Clean console output

### 5. Take Screenshot (if needed)

```
Take screenshot to verify visual state
```

## Common Issues to Check

### Visual Issues

- [ ] Objects render correctly
- [ ] Materials display properly
- [ ] Animations are smooth
- [ ] No visual glitches

### Performance Issues

- [ ] Frame rate is acceptable
- [ ] No stuttering/lag
- [ ] No memory leaks (check console)

### Interaction Issues

- [ ] Controls respond correctly
- [ ] Input works as expected
- [ ] Multi-state interactions work

## Cleanup After Testing

```bash
# Kill dev server when done
# Free up ports 2567, 3000
```
