# Figma Integration Skill

> **Skill**: ta-figma-integration
> **Agent**: Tech Artist
> **Purpose**: Extract designs from Figma and convert to React components

## Overview

This skill enables the Tech Artist agent to integrate with Figma MCP to:
- Read Figma design files
- Extract design tokens (colors, typography, spacing)
- Analyze component structure
- Generate React component code from Figma designs

## When to Use

Use this skill when:
- Creating new UI components from Figma designs
- Extracting design system tokens
- Validating implementation against design reference
- Converting Figma frames to React code
- Syncing design changes to implementation

## Prerequisites

1. **Figma Desktop App** installed and running (optional)
2. **Figma MCP Server** configured (see `../config/figma-mcp.md`)
3. **Figma Access Token** set in environment
4. **Figma File** with UI designs created

## Configuration

### Environment Variables

```bash
# Required
FIGMA_ACCESS_TOKEN=figd_xxxxxxxx
FIGMA_UI_FILE_KEY=figd_abc123...

# Optional (for Figma Desktop MCP)
FIGMA_DESKTOP_SERVER_URL=http://localhost:3700
```

### File Key Format

Figma file keys are found in the URL:
```
https://www.figma.com/file/{fileKey}/{fileName}
```

Example:
```
https://www.figma.com/file/abc123def456/Arena-Strike-UI
                       ^^^^^^^^^^^^
                       This is the file key
```

## Skill Workflow

### Phase 1: Read Figma File Structure

```
START → List File Nodes → Identify Frames → Get Metadata
```

**Tools to use:**
- `figma_read_file` - Get file metadata
- `figma_list_nodes` - Browse file structure
- `figma_get_node` - Get specific frame/component

**Output**: Structure of Figma file (frames, components, pages)

### Phase 2: Extract Design Tokens

```
Identify Design System Frame → Extract Colors → Extract Typography → Extract Spacing
```

**Design Tokens to Extract:**

| Category | What to Extract | Output Format |
|----------|----------------|---------------|
| **Colors** | All color styles | CSS custom properties |
| **Typography** | Font styles, sizes | Typography token object |
| **Spacing** | Grid, layout values | Spacing scale object |
| **Effects** | Shadows, glows | CSS box-shadow values |

**Output Format:**

```typescript
// tokens/colors.ts
export const FIGMA_COLORS = {
  bg_black: '#0a0a0a',
  bg_charcoal: '#1a1a1a',
  silver_200: '#c0c0c0',
  red_500: '#b91c1c',
  // ... etc
};

// tokens/typography.ts
export const FIGMA_TYPOGRAPHY = {
  logo: {
    fontFamily: 'Orbitron',
    fontSize: 72,
    fontWeight: 900,
  },
  // ... etc
};
```

### Phase 3: Analyze Component Structure

```
Select Component → Get Node Data → Analyze Layers → Extract Properties
```

**Component Properties to Extract:**

| Property | Description | Mapping |
|----------|-------------|---------|
| `width` | Component width | CSS `width` |
| `height` | Component height | CSS `height` |
| `fills` | Background colors | CSS `background` |
| `strokes` | Border colors | CSS `border` |
| `effects` | Shadows, glows | CSS `box-shadow` |
| `children` | Child layers | Nested React components |
| `textAlign` | Text alignment | CSS `text-align` |
| `fontSize` | Text size | CSS `font-size` |

### Phase 4: Generate React Code

```
Component Analysis → TypeScript Types → Component Code → CSS Styles
```

**Code Generation Pattern:**

```typescript
// Component: UT3Button
import { motion } from 'framer-motion';

interface UT3ButtonProps {
  variant?: 'primary' | 'secondary';
  size?: 'sm' | 'md' | 'lg';
  children: React.ReactNode;
  onClick?: () => void;
}

export function UT3Button({
  variant = 'primary',
  size = 'md',
  children,
  onClick
}: UT3ButtonProps) {
  return (
    <motion.button
      className={`ut3-button ut3-button--${variant} ut3-button--${size}`}
      onClick={onClick}
      whileHover={{ scale: 1.05 }}
      whileTap={{ scale: 0.97 }}
    >
      {children}
    </motion.button>
  );
}
```

## MCP Tool Reference

### figma_read_file

Read file metadata and basic information.

```typescript
// Usage
const fileInfo = await figma_read_file({
  fileKey: FIGMA_UI_FILE_KEY
});

// Returns
{
  name: "Arena Strike UI",
  lastModified: "2025-01-28T10:00:00Z",
  version: "1.0",
  thumbnailUrl: "https://..."
}
```

### figma_list_nodes

List all nodes in a file (frames, components, pages).

```typescript
// Usage
const nodes = await figma_list_nodes({
  fileKey: FIGMA_UI_FILE_KEY
});

// Returns
[
  { id: "node-1", name: "Start Screen", type: "FRAME" },
  { id: "node-2", name: "Main Menu", type: "FRAME" },
  { id: "node-3", name: "Button", type: "COMPONENT" }
]
```

### figma_get_node

Get detailed information about a specific node.

```typescript
// Usage
const frame = await figma_get_node({
  fileKey: FIGMA_UI_FILE_KEY,
  nodeId: "node-1", // Frame, component, or layer ID
  depth: "components" // Include component definitions
});

// Returns
{
  id: "node-1",
  name: "Start Screen",
  type: "FRAME",
  absoluteBoundingBox: { width: 1920, height: 1080, x: 0, y: 0 },
  fills: [{ type: "SOLID", color: { r: 0.1, g: 0.1, b: 0.1, a: 1 }}],
  children: [ /* ... */ ]
}
```

### figma_get_components

Get all component definitions from the file.

```typescript
// Usage
const components = await figma_get_components({
  fileKey: FIGMA_UI_FILE_KEY
});

// Returns
[
  {
    id: "comp-1",
    name: "Button / Primary",
    description: "Primary action button",
    key: "button-primary"
  }
]
```

### figma_get_styles

Get all style definitions (colors, text, effects).

```typescript
// Usage
const styles = await figma_get_styles({
  fileKey: FIGMA_UI_FILE_KEY
});

// Returns
[
  {
    id: "style-1",
    name: "Colors / Background / Primary",
    styleType: "COLOR",
    value: { r: 0.04, g: 0.04, b: 0.04, a: 1 }
  }
]
```

## Code Generation Templates

### Component Template

```typescript
// Generate from Figma frame/component
async function generateComponent(figmaNodeId: string) {
  const node = await figma_get_node({
    fileKey: FIGMA_UI_FILE_KEY,
    nodeId: figmaNodeId
  });

  const componentName = toPascalCase(node.name);
  const props = extractProps(node);
  const styles = extractStyles(node);

  return `
// Generated from Figma: ${node.name}
// File: ${FIGMA_UI_FILE_KEY}
// Node ID: ${figmaNodeId}

import { motion } from 'framer-motion';

export interface ${componentName}Props {
  ${props.map(p => `${p.name}: ${p.type};`).join('\n  ')}

export function ${componentName}({
  ${props.map(p => p.name).join(',\n  ')}
}: ${componentName}Props) {
  return (
    <motion.div
      className="${toKebabCase(componentName)}"
      style={{${styles.map(s => `  ${s.property}: ${s.value};`).join('\n')}}}
    >
      {/* Render child layers */}
      ${node.children?.map(child => generateLayerCode(child)).join('\n      '))}
    </motion.div>
  );
}
  `;
}
```

### CSS Token Template

```typescript
// Generate CSS variables from Figma styles
async function generateCSSVariables() {
  const styles = await figma_get_styles({
    fileKey: FIGMA_UI_FILE_KEY
  });

  const colorStyles = styles.filter(s => s.styleType === 'COLOR');
  const cssVars = colorStyles.map(style => {
    const varName = toKebabCase(style.name).replace(/colors-//g, '');
    const hex = rgbToHex(style.value);
    return `--ut3-${varName}: ${hex};`;
  });

  return `:root {\n  ${cssVars.join('\n  ')}\n}`;
}
```

## Helper Functions

```typescript
// Convert RGB to hex
function rgbToHex(rgb: { r: number; g: number; b: number; a: number }): string {
  const toHex = (n: number) => Math.round(n * 255).toString(16).padStart(2, '0');
  const a = rgb.a < 1 ? `${rgb.a.toFixed(2)}` : '';
  return `#${toHex(rgb.r)}${toHex(rgb.g)}${toHex(rgb.b)}${a}`;
}

// Convert PascalCase to kebab-case
function toKebabCase(str: string): string {
  return str.replace(/([A-Z])/g, '-$1').toLowerCase();
}

// Extract component props from Figma node
function extractProps(node: FigmaNode): PropDefinition[] {
  const props: PropDefinition[] = [];

  // Check for variants → create prop
  if (node.componentPropertyDefinitions) {
    node.componentPropertyDefinitions.forEach(def => {
      props.push({
        name: def.id,
        type: figmaTypeToTypeScript(def.type),
        defaultValue: def.defaultValue,
        description: def.description
      });
    });
  }

  return props;
}

// Figma type to TypeScript type mapping
function figmaTypeToTypeScript(figmaType: string): string {
  const mapping = {
    'BOOLEAN': 'boolean',
    'INSTANCE_SWAP': 'ReactNode',
    'TEXT': 'string',
    'VARIANT': 'string',
    'NUMBER': 'number'
  };
  return mapping[figmaType] || 'any';
}
```

## Task Checklist

When using this skill, follow this checklist:

- [ ] Figma MCP server is running
- [ ] Access token is valid
- [ ] File key is configured
- [ ] Design file is accessible
- [ ] Design system frame exists in Figma
- [ ] Components are properly named
- [ ] Layer structure is clean (no excessive nesting)
- [ ] Component properties are defined
- [ ] Styles are documented with descriptions

## Common Issues

### Issue: Node not found

**Cause**: Incorrect node ID or file key

**Solution**:
1. Use `figma_list_nodes` to browse file structure
2. Copy correct node ID from results
3. Verify file key matches URL

### Issue: Missing component properties

**Cause**: Component properties not defined in Figma

**Solution**:
1. Open component in Figma
2. Go to Component properties panel
3. Add property definitions with types and defaults

### Issue: Cannot access file

**Cause**: Access token lacks permission

**Solution**:
1. Check token has "View" permission
2. Verify you're logged into correct Figma account
3. Regenerate token if expired

## Integration with Project Structure

### Output Locations

Generated code should be placed in:

| Content Type | Location |
|--------------|----------|
| Design Tokens | `src/styles/tokens/figma-tokens.css` |
| Component Types | `src/components/ui/ut3/types.ts` |
| Component Code | `src/components/ui/ut3/*.tsx` |
| Utilities | `src/utils/figma-helpers.ts` |

### Example File Structure After Generation

```
src/
├── styles/
│   └── tokens/
│       ├── figma-tokens.css      (Generated from Figma colors)
│       └── figma-typography.ts   (Generated from Figma text styles)
├── components/
│   └── ui/
│       └── ut3/
│           ├── UT3Button.tsx      (Generated from Figma component)
│           ├── UT3Panel.tsx       (Generated from Figma component)
│           └── types.ts            (Generated TypeScript types)
└── utils/
    └── figma-helpers.ts           (Figma conversion utilities)
```

## References

- [Figma Official MCP Guide](https://help.figma.com/hc/en-us/articles/32132100833559-Guide-to-the-Figma-MCP-server)
- [Figma Desktop MCP Setup](https://help.figma.com/hc/en-us/articles/35281186390679-Figma-MCP-collection-How-to-setup-the-Figma-desktop-MCP-server)
- [Claude Code + Figma MCP](https://www.builder.io/blog/claude-code-figma-mcp-server)
- [MCP Build Documentation](https://modelcontextprotocol.io/docs/develop/build-server)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-28 | Initial skill creation |
