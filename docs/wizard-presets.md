# Wizard Presets Documentation

This document describes the 14 built-in presets available in the PRD Starter Wizard.

## Overview

Presets provide pre-configured Ralph Orchestra setups for common project types. Each preset includes:
- Agent selection and configuration
- Skill sets per agent
- Sub-agent assignments
- MCP server configurations
- Orchestration mode recommendations
- Quality standards

## Using Presets

### Quick Start Mode

When using the PRD Starter wizard in Quick Start mode, simply select a preset and provide your project name. The wizard will generate a complete Ralph Orchestra setup based on the preset configuration.

### Customizing Presets

After selecting a preset in Quick Start mode, you can:
- Continue with customization (switches to Standard Mode)
- Add or remove skills per agent
- Add or remove sub-agents per agent
- Adjust MCP server configurations
- Modify quality standards

## Available Presets

### 🎮 Game Development Presets

#### Indie Game Dev

**File:** `.claude/presets/indie-game-dev.json`

**Best For:** Solo developers or small teams creating 3D games with React Three Fiber

**Agents:** PM, Developer, Tech Artist, QA, Game Designer

**Skills:** 45 game dev skills including:
- R3F fundamentals, physics, materials
- Performance optimization (instancing, LOD)
- Asset loading (Vite 6, audio, models, textures)
- Game design (GDD, mechanics, levels)

**Sub-Agents:** 18 sub-agents

**Orchestration:** Sequential (token-efficient for solo devs)

**Tech Stack:** React Three Fiber

---

#### Game Studio

**File:** `.claude/presets/game-studio.json`

**Best For:** Professional game studios building multiplayer games

**Agents:** PM, Developer, Tech Artist, QA, Game Designer

**Skills:** 50+ full stack skills including:
- All Indie Game Dev skills
- Complete multiplayer suite (Colyseus, server-authoritative, client prediction)
- Advanced performance optimization
- Comprehensive testing

**Sub-Agents:** 25+ sub-agents

**Orchestration:** Event-Driven (parallel for teams)

**Tech Stack:** React Three Fiber + Colyseus

---

#### Mobile Game

**File:** `.claude/presets/mobile-game.json`

**Best For:** iOS/Android mobile games with performance focus

**Agents:** PM, Developer, Tech Artist, QA

**Skills:** Mobile-optimized skills including:
- Mobile performance optimization
- Haptics (vibration feedback)
- Touch-optimized UI patterns
- Asset optimization for mobile

**Sub-Agents:** Mobile-specific sub-agents

**Orchestration:** Sequential (token-efficient)

**Tech Stack:** React Three Fiber + Mobile Optimizations

---

#### Multiplayer Arena

**File:** `.claude/presets/multiplayer-arena.json`

**Best For:** Server-authoritative multiplayer games (FPS, battle royale, etc.)

**Agents:** PM, Developer, Tech Artist, QA, Game Designer

**Skills:** All networking + game skills:
- Complete Colyseus integration
- Server-authoritative architecture
- Client-side prediction (movement, shooting)
- Anti-cheat validation
- Multiplayer visual feedback

**Sub-Agents:** Colyseus-focused sub-agents

**Orchestration:** Event-Driven

**Tech Stack:** React Three Fiber + Colyseus + Client Prediction

---

### 🌐 Web Application Presets

#### Modern Web App

**File:** `.claude/presets/modern-web-app.json`

**Best For:** React/Vue/Svelte single-page applications

**Agents:** PM, Developer, QA

**Skills:** 25 web skills including:
- TypeScript patterns
- UI animations (Framer Motion)
- Performance basics
- Browser testing

**Sub-Agents:** 10 web sub-agents

**Orchestration:** Sequential

**Tech Stack:** React 18 + Vite + TypeScript

---

#### Full Stack SaaS

**File:** `.claude/presets/full-stack-saas.json`

**Best For:** Complete web applications with backend

**Agents:** PM, Developer, QA

**Skills:** 35 full-stack skills including:
- Frontend + backend patterns
- State management
- API integration
- Auth and billing patterns

**Sub-Agents:** 15 full-stack sub-agents

**Orchestration:** Event-Driven

**Tech Stack:** Next.js + TypeScript

---

#### Dashboard/Analytics

**File:** `.claude/presets/dashboard-analytics.json`

**Best For:** Data-heavy applications with charts and visualization

**Agents:** PM, Developer, QA

**Skills:** Data visualization skills:
- Chart libraries
- Data processing
- Performance optimization for large datasets
- UI polish for dashboards

**Sub-Agents:** Chart/visualization focused

**Orchestration:** Sequential

**Tech Stack:** React + Chart Libraries

---

#### Content Platform

**File:** `.claude/presets/content-platform.json`

**Best For:** Blogs, documentation sites, CMS platforms

**Agents:** PM, Developer, QA, Game Designer

**Skills:** CMS + SEO skills:
- Content management
- SEO optimization
- Markdown/MDX processing
- Documentation structure

**Sub-Agents:** Content-focused

**Orchestration:** Sequential

**Tech Stack:** SvelteKit + MDX

---

### 🏢 Business & Commerce Presets

#### E-Commerce Store

**File:** `.claude/presets/ecommerce-store.json`

**Best For:** Online stores with shopping cart and checkout

**Agents:** PM, Developer, QA, Game Designer

**Skills:** Payment + inventory skills:
- Shopping cart patterns
- Payment integration
- Inventory management
- Checkout flow optimization

**Sub-Agents:** Domain-specific

**Orchestration:** Event-Driven

**Tech Stack:** Next.js + Stripe

---

#### SaaS Product

**File:** `.claude/presets/saas-product.json`

**Best For:** Subscription-based products with recurring billing

**Agents:** PM, Developer, QA, Game Designer

**Skills:** Auth + billing + subscription:
- Authentication patterns
- Subscription management
- Billing integration
- User onboarding flows

**Sub-Agents:** Full-stack

**Orchestration:** Event-Driven

**Tech Stack:** Next.js + Auth + Billing

---

#### Enterprise Suite

**File:** `.claude/presets/enterprise-suite.json`

**Best For:** Large-scale business applications

**Agents:** PM, Developer, QA

**Skills:** Security + compliance:
- Enterprise security patterns
- Compliance frameworks
- Audit logging
- Role-based access control

**Sub-Agents:** Enterprise-focused

**Orchestration:** Event-Driven

**Tech Stack:** Enterprise React + TypeScript

---

### 🔧 Technical Presets

#### API Server

**File:** `.claude/presets/api-server.json`

**Best For:** Node.js/Python/Go API services

**Agents:** PM, Developer, QA

**Skills:** Server + database:
- API design patterns
- Database integration
- Authentication
- Rate limiting

**Sub-Agents:** Backend

**Orchestration:** Sequential

**Tech Stack:** Node.js + TypeScript + PostgreSQL

---

#### Data/ML Pipeline

**File:** `.claude/presets/data-ml-pipeline.json`

**Best For:** ML models and data processing

**Agents:** PM, Developer, QA

**Skills:** Python + TensorFlow:
- Data processing
- Model training
- Pipeline orchestration
- Model deployment

**Sub-Agents:** Data pipeline

**Orchestration:** Sequential

**Tech Stack:** Python + TensorFlow + Jupyter

---

#### DevOps/Infrastructure

**File:** `.claude/presets/devops-infrastructure.json`

**Best For:** CI/CD, deployment, and infrastructure automation

**Agents:** PM, Developer, QA

**Skills:** CI/CD + Terraform:
- Infrastructure as code
- CI/CD pipelines
- Container orchestration
- Monitoring

**Sub-Agents:** Infrastructure

**Orchestration:** Sequential

**Tech Stack:** Terraform + Docker + GitHub Actions

---

## Creating Custom Presets

To create a custom preset:

1. Copy an existing preset file from `.claude/presets/`
2. Modify the configuration as needed
3. Save as a new `.json` file in `.claude/presets/`
4. The preset will automatically appear in the wizard options

### Preset File Structure

```json
{
  "name": "custom-preset",
  "displayName": "Custom Preset",
  "category": "Custom",
  "description": "Description of your custom preset",
  "recommendedTechStack": "Your Tech Stack",
  "agents": {
    "pm": {
      "enabled": true,
      "skills": ["skill1", "skill2"],
      "subAgents": ["subagent1"],
      "mcpServers": ["github", "filesystem"]
    },
    "developer": { ... },
    "techartist": { ... },
    "qa": { ... },
    "gamedesigner": { ... }
  },
  "orchestration": {
    "recommendedMode": "sequential",
    "maxIterations": 200,
    "contextResetThreshold": 70
  },
  "qualityStandards": {
    "typescriptStrictness": "strict",
    "testCoverageTarget": 80,
    "noAnyTypes": true,
    "noTsIgnore": true
  }
}
```

## See Also

- [Wizard Skill Catalog](wizard-skill-catalog.md) - Complete list of all skills
- [Wizard Sub-Agent Catalog](wizard-subagent-catalog.md) - Complete list of all sub-agents
- [../.claude/skills/ralph-prd-starter/SKILL.md](../.claude/skills/ralph-prd-starter/SKILL.md) - Wizard skill documentation
