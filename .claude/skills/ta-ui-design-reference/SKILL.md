# UI Design Reference Skill

> **Skill**: ta-ui-design-reference
> **Agent**: Tech Artist
> **Purpose**: Create and maintain Figma design references for UI implementation

## Overview

This skill enables the Tech Artist to:
- Create Figma design frames based on specifications
- Reference UT3 design while creating original assets
- Set up design system in Figma for Arena Strike TPS
- Maintain design-to-code workflow

## When to Use

Use this skill when:
- Starting UI refactor work (before coding)
- Need visual reference for complex UI components
- Creating design system documentation
- Validating implementation against design

## Prerequisites

1. **Figma Account** - Free or professional
2. **Figma Desktop App** (optional but recommended)
3. **Basic Figma knowledge** - Frames, components, styles

## Figma File Structure

Create this structure in Figma for Arena Strike TPS:

```
Arena Strike TPS - UI Design
├── 📁 Design System
│   ├── 🎨 Colors
│   │   ├── Backgrounds
│   │   ├── Primary (Silver)
│   │   ├── Accent (Red)
│   │   └── Text Colors
│   ├── ✏️ Typography
│   │   ├── Display (Orbitron)
│   │   ├── Menu (Rajdhani)
│   │   └── Monospace (JetBrains Mono)
│   ├── 📐 Spacing
│   │   ├── Scale (8px base unit)
│   │   └── Layout Grid (16:9)
│   └── 🧩 Component Styles
│       ├── Buttons
│       ├── Panels
│       ├── Menu Items
│       └── Effects
├── 📁 Screens (1920x1080 reference)
│   ├── 01 - Start Screen
│   ├── 02 - Main Menu
│   ├── 03 - Character Selection
│   ├── 04 - Settings
│   └── 05 - Credits
└── 📁 Assets
    ├── UI Textures (carbon fiber, brushed metal)
    └── Icons
```

## UT3 Design Reference Guide

### Color Extraction from UT3

| Element | UT3 Value | CSS Variable |
|---------|-----------|-------------|
| **Background (Black)** | #0a0a0a | `--ut3-bg-black` |
| **Background (Charcoal)** | #1a1a1a | `--ut3-bg-charcoal` |
| **Background (Blue-Gray)** | #2a2a2a → #1a1a1a | `linear-gradient(180deg, #2a2a2a, #1a1a1a)` |
| **Logo Silver** | #c0c0c0 | `--ut3-silver-200` |
| **Logo White Glow** | #ffffff | `--ut3-silver-50` |
| **Logo "III" Red (top)** | #8B0000 | `--ut3-red-600` |
| **Logo "III" Red (bottom)** | #FF0000 | `--ut3-red-glow` |
| **Menu Item (Normal)** | #aaaaaa | `--ut3-text-normal` |
| **Menu Item (Selected)** | #ffffff | `--ut3-text-selected` |
| **Menu Border** | #000000 | `--ut3-border-dark` |
| **Unreal Engine Gold** | #FFD700 | (for game logo reference) |

### Typography from UT3

| Element | Font | Size | Weight | Letter Spacing |
|---------|------|------|--------|---------------|
| **"Unreal Tournament"** | Angular Serif | ~72px | Bold (900) | ~0.05em |
| **Menu Items** | Sans-serif (condensed) | ~28px | Bold (700) | ~0.1em |
| **User Status** | Sans-serif | ~12px | Normal (400) | Normal |
| **XLink Kai** | Sans-serif | ~10px | Normal | Normal |

**Font Recommendations for Figma:**
- **Display/Logo**: Orbitron (already in project) - Heavy weight
- **Menu Items**: Rajdhani (already in project) - Semi-bold
- **UI Text**: Rajdhani - Regular/Medium

### Panel/Frame Design from UT3

**Carbon Fiber Panel (right side, 40% width):**

1. **Background**: Dark with carbon fiber weave texture
   - In Figma: Use image fill with carbon pattern OR
   - Create using 4 radial gradients in a grid pattern

2. **Border**: 1px, dark gray (#333), rough/torn left edge
   - In Figma: Use SVG mask or clip-path with jagged edge

3. **Effects**:
   - Inner glow at top (subtle white, ~10% opacity)
   - Drop shadow on right (2px blur, black)

### Button/Menu Item Design from UT3

**Normal State:**
- Background: Transparent
- Text: #aaaaaa (light gray)
- Border: None
- Spacing: 20px vertical gap
- Bottom separator: 1px, #333

**Selected State:**
- Background: Transparent
- Text: #ffffff (white)
- Border: 1px, solid #000000 (black), 2px radius corners
- Shadow: Subtle white glow
- Inner shadow (optional depth effect)

**Hover State (implied):**
- Same as selected but with red glow instead of white

### Layout Dimensions (1920x1080 reference)

| Element | Position | Size |
|--------|----------|------|
| **Logo** | Center X, top ~15% | ~400px wide |
| **Menu Items** | Center X in panel, Y ~30%-75% | ~360px wide |
| **Panel Width** | Right ~40% | ~768px (1920 × 0.4) |
| **3D Scene** | Left ~60% | ~1152px |
| **Player Panel** | Bottom left, 64px from edges | ~280px wide |
| **Version Info** | Bottom left (below player panel) | - |
| **Status Icons** | Bottom right | - |

## Creating Figma Frames from Scratch

### Step 1: Create Frame

1. Create new frame: `F2` → Type "Start Screen"
2. Set dimensions: `1920 × 1080`
3. Add description: "Reference: UT3 PS3 main menu style"

### Step 2: Create Background Panel

1. Draw rectangle: `R` → Rectangle tool
2. Position: Right side, 40% width (x: 1152, width: 768, height: 1080)
3. Fill: #0a0a0a (pure black)
4. Add carbon fiber texture (see below)

### Step 3: Create Carbon Fiber Texture in Figma

**Option A: Using Pattern Fill**
1. Create 8×8px frame
2. Draw diagonal lines at 45°
3. Export as SVG
4. Import as pattern fill in main frame

**Option B: Using Multiple Gradients**
1. Add 4 radial gradients (circles) in 2×2 grid
2. Set each to: Type: Radial, Stops: 0%=#1a1a1a, 100%=#0a0a0a
3. Blend mode: Overlay or Soft Light

### Step 4: Create Torn Edge Effect

1. Use Pen tool or Vector tool
2. Draw jagged line along left edge
3. Create mask from selection
4. Apply to panel

### Step 5: Create Logo

1. Add text: `T` → Text tool
2. Font: Orbitron (or similar angular font)
3. Size: 72px
4. Weight: Black (900)
5. Color: Silver gradient
6. Add text shadow: 2px down, 2px right, black

### Step 6: Create Menu Items

1. Add text for each menu item
2. Font: Rajdhani, Semi-bold (600), 28px
3. Color: #aaaaaa
4. Spacing: 20px vertical gap
5. Add separator lines between items: 1px height, #333

### Step 7: Create Selected State Example

1. Duplicate one menu item
2. Change text to: #ffffff
3. Add border: 1px, stroke: #000000
4. Add corner radius: 2px
5. Add inner shadow: 1px, black, inset

### Step 8: Add Player Status Panel

1. Draw rectangle at bottom left: 280px wide, 100px tall
2. Position: 64px from bottom, 64px from left
3. Fill: Semi-transparent black (#000000aa)
4. Border: 1px, silver/30% (#c0c0c030)
5. Add avatar circle, name, level, stats

## Component Templates for Figma

### UT3Button Component

```
States: default, hover, active, disabled

Default:
- Size: 160px × 48px (md), 200px × 64px (lg)
- Background: Transparent
- Border: None
- Text: #aaaaaa, 18px (md) or 24px (lg)
- Font: Rajdhani, Semi-bold

Hover:
- Background: Transparent
- Text: #ffffff
- Glow: 1px white
- Border: 1px #c0c0c0

Active (pressed):
- Scale: 0.97
- Background: Silver 10%
- Text: #000000 (inverted)

Disabled:
- Opacity: 0.5
- Cursor: not-allowed
```

### UT3Panel Component

```
Variants: default, elevated, glass

Default:
- Background: #0a0a0a with carbon fiber
- Border: 1px, #333
- Corner radius: 0px (sharp) or 2px (slight)
- Shadow: 0 8px 32px rgba(0,0,0,0.6)

Elevated:
- Adds inner glow at top: 0 1px 0 rgba(255,255,255,0.1)
- Border: 1px, #555

Glass:
- Background: rgba(10,10,10,0.95)
- Backdrop blur: 4px
- Border: 1px, rgba(192,192,192,0.3)
```

## Export Settings

### For Development

When exporting designs for implementation:

1. **Export assets as:**
   - SVG for icons and simple shapes
   - PNG at 2x resolution for textures
   - CSS for style tokens

2. **Export frame as:**
   - Screenshot: 1x and 2x resolution
   - CSS specifications
   - Component properties

### Handoff to Code

For each frame/component, document:

| Property | Value | Notes |
|----------|-------|-------|
| **Frame Name** | Screen/Component | PascalCase |
| **Dimensions** | Width × Height | In pixels |
| **Background** | Fill type + hex | Include opacity |
| **Border** | Width + color + radius | All values |
| **Font** | Family + size + weight | Include line-height |
| **Effects** | Shadow + glow + blur | CSS box-shadow format |
| **Spacing** | Margins + padding | In pixels |

## Design Review Checklist

Before marking design ready for implementation:

- [ ] All colors documented in Design System page
- [ ] Typography tokens created
- [ ] Component variants defined
- [ ] Layout grid specified (16:9 reference)
- [ ] States documented (default, hover, active, disabled)
- [ ] Spacing consistent (8px base unit)
- [ ] Assets exported (icons, textures)
- [ ] Z-index/order specified
- [ ] Responsive breakpoints noted
- [ ] Accessibility considered (contrast ratios)

## Figma to Code Workflow

```
[Design in Figma] → [Extract Tokens] → [Create Components] → [Write Tests] → [Implement]
```

1. **Design in Figma**: Create frames matching specifications
2. **Extract Tokens**: Use `ta-figma-integration` skill to read Figma
3. **Create Components**: Generate React components from Figma
4. **Write Tests**: Create E2E tests for each component
5. **Implement**: Write code in worktree, validate, commit

## Resources

- [Figma](https://www.figma.com) - Design tool
- [Figma MCP Guide](https://help.figma.com/hc/en-us/articles/32132100833559-Guide-to-the-Figma-MCP-server) - MCP setup
- [Figma Desktop MCP Setup](https://help.figma.com/hc/en-us/articles/35281186390679-Figma-MCP-collection-How-to-setup-the-Figma-desktop-MCP-server) - Desktop app setup

## Quick Start: Create Start Screen Frame

1. Create frame: 1920×1080, name "01 - Start Screen"
2. Add 3D scene placeholder: Rectangle, left 60%, dark gray with "3D Scene" label
3. Add panel: Rectangle, right 40%, #0a0a0a, carbon texture
4. Add logo: "ARENA STRIKE" at top center of panel, Orbitron 72px
5. Add menu items: "Quick Play", "Main Menu" vertically stacked
6. Add player panel at bottom left
7. Add torn edge effect to panel left side
8. Export as PNG for reference

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-28 | Initial skill creation - UT3 reference guide |
