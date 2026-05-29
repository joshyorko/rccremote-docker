# Rails RCC Remote - Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the card-heavy RCC Remote UI into a sleek 37signals-inspired mission control with bold typography, zero nested cards, and cutting-edge CSS/interactions.

**Architecture:** Foundation-first approach: establish CSS tokens and base styles, modernize application layout, then systematically redesign each view (dashboard, workspaces, catalogs, bundles) removing all card components and replacing with typography-driven zones, borders, and horizontal rhythms.

**Tech Stack:** Tailwind CSS (utilities), custom CSS (cascade layers, container queries), Stimulus controllers, View Transitions API, Inter Display/Berkeley Mono fonts

---

## File Structure

**CSS Architecture:**
```
app/assets/stylesheets/
├── application.css              # Main imports, cascade layers
├── config/
│   ├── tokens.css              # Design tokens (colors, spacing, type)
│   ├── typography.css          # Font faces and system
│   └── reset.css               # Modern CSS reset
├── components/
│   ├── navigation.css          # Top bar, Omakase menu
│   ├── dashboard.css           # Dashboard-specific styles
│   ├── workspaces.css          # Workspace browser styles
│   ├── forms.css               # Input/button styles
│   └── utilities.css           # Reusable utility patterns
└── animations.css              # View Transitions, micro-interactions
```

**JavaScript:**
```
app/javascript/controllers/
├── theme_controller.js         # Existing, simplified
├── omakase_menu_controller.js  # Enhanced with View Transitions
└── transitions_controller.js   # Global View Transitions setup
```

**Views:**
```
app/views/
├── layouts/
│   └── application.html.erb    # Keep as-is, already solid
├── dashboard/
│   └── index.html.erb          # Complete redesign
├── robots/
│   ├── index.html.erb          # Workspaces list - redesign
│   └── show.html.erb           # Workspace detail - redesign
├── catalogs/
│   └── index.html.erb          # Catalogs list - redesign
├── hololib_zips/
│   └── index.html.erb          # Bundles list - redesign
└── shared/
    └── _stat_card.html.erb     # DELETE THIS
```

---

## Task 1: Create CSS Foundation & Design Tokens

**Files:**
- Create: `app/assets/stylesheets/config/tokens.css`
- Create: `app/assets/stylesheets/config/typography.css`
- Create: `app/assets/stylesheets/config/reset.css`
- Modify: `app/assets/stylesheets/application.css`

### Step 1: Create design tokens file

Create `app/assets/stylesheets/config/tokens.css`:

```css
@layer config {
  :root {
    /* Colors */
    --gold: #FFD33D;
    --gold-muted: #C4A000;
    --ink: #0A0B0F;
    --ink-raised: #12131A;
    --ink-surface: #1A1D26;
    --snow: #F7F8FA;
    --gray-light: #E5E7EB;
    --gray: #9CA3AF;
    --gray-dark: #6B7280;
    --success: #22C55E;
    --danger: #EF4444;
    --warning: #F59E0B;

    /* Spacing */
    --sp-xs: 0.25rem;
    --sp-sm: 0.5rem;
    --sp-md: 1rem;
    --sp-lg: 1.5rem;
    --sp-xl: 2rem;
    --sp-2xl: 3rem;
    --sp-3xl: 4rem;

    /* Typography */
    --font-display: 'Inter Display', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    --font-body: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    --font-mono: 'Berkeley Mono', 'Courier New', monospace;

    /* Z-index */
    --z-dropdown: 100;
    --z-sticky: 200;
    --z-fixed: 300;
    --z-modal: 400;
  }

  [data-theme="dark"] {
    --text-primary: var(--snow);
    --text-secondary: var(--gray);
    --text-muted: var(--gray-dark);
    --bg-primary: var(--ink);
    --bg-raised: var(--ink-raised);
    --bg-surface: var(--ink-surface);
    --border-color: rgba(255, 211, 61, 0.1);
  }

  [data-theme="light"] {
    --text-primary: var(--ink);
    --text-secondary: var(--gray-dark);
    --text-muted: var(--gray);
    --bg-primary: var(--snow);
    --bg-raised: white;
    --bg-surface: #F3F4F6;
    --border-color: rgba(0, 0, 0, 0.1);
  }
}
```

### Step 2: Create typography system

Create `app/assets/stylesheets/config/typography.css`:

```css
@import url('https://rsms.me/inter/inter.css');

@font-face {
  font-family: 'Berkeley Mono';
  src: url('https://cdn.jsdelivr.net/npm/berkeley-mono@0.1.0/BerkeleyMono-Regular.woff2') format('woff2');
  font-weight: 400;
  font-style: normal;
}

@layer config {
  html {
    font-size: clamp(14px, 1vw, 16px);
  }

  body {
    font-family: var(--font-body);
    color: var(--text-primary);
    background: var(--bg-primary);
    line-height: 1.6;
    -webkit-font-smoothing: antialiased;
  }

  /* Display Heading */
  h1, .h1 {
    font-family: var(--font-display);
    font-size: clamp(2.5rem, 8vw, 4.5rem);
    font-weight: 900;
    line-height: 1.1;
    letter-spacing: -0.02em;
    margin: 0;
  }

  /* Large Heading */
  h2, .h2 {
    font-family: var(--font-display);
    font-size: clamp(1.875rem, 5vw, 3rem);
    font-weight: 800;
    line-height: 1.2;
    letter-spacing: -0.01em;
    margin: 0;
  }

  /* Medium Heading */
  h3, .h3 {
    font-family: var(--font-display);
    font-size: clamp(1.25rem, 3vw, 1.875rem);
    font-weight: 700;
    line-height: 1.3;
    margin: 0;
  }

  /* Small Heading */
  h4, .h4, .label {
    font-family: var(--font-body);
    font-size: 0.875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin: 0;
    color: var(--text-secondary);
  }

  /* Body text */
  p, .text {
    margin: 0;
    font-size: 1rem;
  }

  .text-sm {
    font-size: 0.875rem;
  }

  .text-xs {
    font-size: 0.75rem;
  }

  .text-muted {
    color: var(--text-muted);
  }

  /* Code */
  code, pre {
    font-family: var(--font-mono);
    font-size: 0.875rem;
  }
}
```

### Step 3: Create CSS reset

Create `app/assets/stylesheets/config/reset.css`:

```css
@layer config {
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }

  html, body {
    height: 100%;
  }

  button, input, textarea, select {
    font: inherit;
    color: inherit;
  }

  button {
    cursor: pointer;
    border: none;
    background: none;
  }

  a {
    color: inherit;
    text-decoration: none;
  }

  img {
    display: block;
    max-width: 100%;
  }

  ul, ol {
    list-style: none;
  }
}
```

### Step 4: Update application.css to import new foundation

Modify `app/assets/stylesheets/application.css`:

```css
@import "tailwindcss/base";
@import "tailwindcss/components";
@import "tailwindcss/utilities";

/* Config layer - design tokens first */
@import "config/reset.css";
@import "config/tokens.css";
@import "config/typography.css";

/* Component layer */
@import "components/navigation.css";
@import "components/dashboard.css";
@import "components/workspaces.css";
@import "components/forms.css";
@import "components/utilities.css";

/* Animations layer */
@import "animations.css";

/* FOUT mitigation */
@supports (font-variation-settings: normal) {
  body {
    font-feature-settings: 'cv06', 'cv11';
  }
}
```

### Step 5: Commit foundation

Run:
```bash
git add app/assets/stylesheets/config/ app/assets/stylesheets/application.css
git commit -m "feat: establish CSS foundation with design tokens, typography, and reset"
```

---

## Task 2: Create Navigation & Global Styles

**Files:**
- Create: `app/assets/stylesheets/components/navigation.css`
- Create: `app/assets/stylesheets/components/utilities.css`

### Step 1: Create navigation styles

Create `app/assets/stylesheets/components/navigation.css`:

```css
@layer components {
  /* Top Bar */
  .top-bar {
    position: sticky;
    top: 0;
    z-index: var(--z-sticky);
    display: grid;
    grid-template-columns: auto 1fr auto;
    align-items: center;
    gap: var(--sp-lg);
    padding: var(--sp-md) var(--sp-xl);
    background: rgba(var(--bg-raised-rgb), 0.95);
    backdrop-filter: blur(12px);
    border-bottom: 1px solid var(--border-color);
  }

  .top-bar__lane {
    display: flex;
    align-items: center;
    gap: var(--sp-lg);
  }

  .top-bar__lane--left {
    min-width: 0;
  }

  .top-bar__lane--right {
    margin-left: auto;
  }

  /* Brand */
  .brand {
    display: flex;
    align-items: center;
    gap: var(--sp-md);
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--text-primary);
    transition: opacity 150ms ease;
  }

  .brand:hover {
    opacity: 0.8;
  }

  .brand-mark {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2.5rem;
    height: 2.5rem;
    background: linear-gradient(135deg, var(--gold) 0%, var(--gold-muted) 100%);
    border-radius: 0.5rem;
    color: var(--ink);
    font-weight: 700;
    font-size: 0.875rem;
  }

  .brand-text {
    display: flex;
    flex-direction: column;
    gap: 0.125rem;
  }

  .brand-text strong {
    display: block;
    font-size: 0.875rem;
    font-weight: 600;
  }

  .brand-text small {
    display: block;
    font-size: 0.75rem;
    color: var(--text-secondary);
    font-weight: 400;
  }

  /* Omakase Menu */
  .omakase-center {
    display: flex;
    align-items: center;
    gap: var(--sp-lg);
  }

  .omakase-trigger {
    display: flex;
    align-items: center;
    gap: var(--sp-sm);
    padding: var(--sp-sm) var(--sp-lg);
    border: 2px solid var(--gold);
    border-radius: 9999px;
    color: var(--text-primary);
    font-size: 0.875rem;
    font-weight: 600;
    background: transparent;
    transition: all 150ms ease;
  }

  .omakase-trigger:hover {
    background: rgba(var(--gold-rgb), 0.05);
  }

  .omakase-trigger:active {
    background: rgba(var(--gold-rgb), 0.1);
  }

  .omakase-trigger-dot {
    display: inline-block;
    width: 0.375rem;
    height: 0.375rem;
    background: var(--gold);
    border-radius: 50%;
  }

  .omakase-trigger-label {
    display: none;
  }

  @media (min-width: 768px) {
    .omakase-trigger-label {
      display: inline;
    }
  }

  .omakase-kbd {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 1.5rem;
    height: 1.5rem;
    padding: 0 0.375rem;
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 0.25rem;
    font-family: var(--font-mono);
    font-size: 0.75rem;
    font-weight: 500;
    color: var(--text-secondary);
  }

  /* Context Pill */
  .omakase-context-pill {
    display: none;
    align-items: center;
    gap: var(--sp-sm);
    padding: var(--sp-sm) var(--sp-lg);
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 9999px;
    font-size: 0.875rem;
  }

  @media (min-width: 1024px) {
    .omakase-context-pill {
      display: flex;
    }
  }

  .omakase-context-label {
    color: var(--text-secondary);
    font-weight: 500;
  }

  .omakase-context-pill strong {
    color: var(--text-primary);
    font-weight: 600;
  }

  /* Omakase Dialog */
  .omakase-dialog {
    position: fixed;
    inset: 0;
    z-index: var(--z-modal);
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(4px);
  }

  .omakase-dialog::backdrop {
    background: transparent;
  }

  .omakase-dialog-shell {
    width: 90%;
    max-width: 48rem;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    background: var(--bg-raised);
    border: 2px solid var(--border-color);
    border-radius: 0.75rem;
    overflow: hidden;
  }

  .omakase-dialog-header {
    display: grid;
    grid-template-columns: 1fr auto;
    align-items: flex-start;
    gap: var(--sp-lg);
    padding: var(--sp-xl);
    border-bottom: 1px solid var(--border-color);
  }

  .omakase-dialog-kicker {
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-secondary);
    margin-bottom: var(--sp-sm);
  }

  .omakase-dialog-title {
    margin-bottom: var(--sp-sm);
  }

  .omakase-dialog-note {
    font-size: 0.875rem;
    color: var(--text-secondary);
  }

  .omakase-dialog-close {
    display: flex;
    align-items: center;
    gap: var(--sp-sm);
  }

  .omakase-icon-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2rem;
    height: 2rem;
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 0.375rem;
    color: var(--text-secondary);
    transition: all 150ms ease;
  }

  .omakase-icon-btn:hover {
    background: var(--bg-primary);
    color: var(--text-primary);
  }

  /* Filter Input */
  .omakase-filter-wrap {
    padding: var(--sp-lg);
    border-bottom: 1px solid var(--border-color);
  }

  .omakase-filter-input {
    width: 100%;
    padding: var(--sp-md) var(--sp-lg);
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    color: var(--text-primary);
    font-size: 1rem;
    transition: all 150ms ease;
  }

  .omakase-filter-input:focus {
    outline: none;
    border-color: var(--gold);
    background: var(--bg-primary);
  }

  .omakase-filter-input::placeholder {
    color: var(--text-muted);
  }

  /* Command Hub */
  .omakase-command-hub {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: var(--sp-xl);
    padding: var(--sp-lg);
    overflow-y: auto;
  }

  .omakase-menu-section {
    display: flex;
    flex-direction: column;
    gap: var(--sp-md);
  }

  .omakase-section-heading {
    padding: 0 var(--sp-md);
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-secondary);
  }

  /* Home Column (Surfaces) */
  .omakase-home-column {
    display: flex;
    flex-direction: column;
    gap: var(--sp-sm);
    min-width: 250px;
  }

  .omakase-home-tile {
    display: grid;
    grid-template-columns: 1fr auto;
    align-items: center;
    gap: var(--sp-md);
    padding: var(--sp-md) var(--sp-lg);
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    text-align: left;
    transition: all 150ms ease;
  }

  .omakase-home-tile:hover {
    background: var(--bg-primary);
    border-color: var(--gold);
  }

  .omakase-home-tile.is-active {
    background: rgba(var(--gold-rgb), 0.1);
    border-color: var(--gold);
  }

  .omakase-home-tile-title {
    display: block;
    font-weight: 600;
    color: var(--text-primary);
    margin-bottom: var(--sp-xs);
  }

  .omakase-home-tile-meta {
    display: block;
    font-size: 0.75rem;
    color: var(--text-secondary);
  }

  /* Menu List */
  .omakase-menu-list {
    display: flex;
    flex-direction: column;
    gap: var(--sp-sm);
  }

  .omakase-menu-item {
    display: grid;
    grid-template-columns: 1fr auto;
    align-items: center;
    gap: var(--sp-md);
    padding: var(--sp-md) var(--sp-lg);
    background: transparent;
    border: 1px solid transparent;
    border-radius: 0.375rem;
    text-align: left;
    transition: all 150ms ease;
  }

  .omakase-menu-item:hover {
    background: var(--bg-surface);
    border-color: var(--border-color);
  }

  .omakase-menu-item-title {
    display: block;
    font-weight: 600;
    color: var(--text-primary);
    margin-bottom: var(--sp-xs);
  }

  .omakase-menu-item-meta {
    display: block;
    font-size: 0.75rem;
    color: var(--text-secondary);
  }

  .omakase-empty {
    padding: var(--sp-xl);
    text-align: center;
    color: var(--text-secondary);
  }

  /* Nav Link */
  .nav-link {
    padding: var(--sp-sm) var(--sp-md);
    color: var(--text-primary);
    font-size: 0.875rem;
    font-weight: 500;
    transition: color 150ms ease;
  }

  .nav-link:hover {
    color: var(--gold);
  }
}
```

### Step 2: Create utilities

Create `app/assets/stylesheets/components/utilities.css`:

```css
@layer components {
  /* App Shell */
  .app-shell {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
  }

  /* Page */
  .page {
    flex: 1;
    overflow: auto;
    padding: var(--sp-2xl) var(--sp-xl);
  }

  /* Sections */
  .page-section {
    margin-bottom: var(--sp-3xl);
  }

  .page-section:last-child {
    margin-bottom: 0;
  }

  /* Page Header */
  .page-header {
    display: grid;
    grid-template-columns: 1fr auto;
    align-items: flex-start;
    gap: var(--sp-xl);
    margin-bottom: var(--sp-2xl);
    padding-bottom: var(--sp-2xl);
    border-bottom: 1px solid var(--border-color);
  }

  .page-header-copy h1 {
    margin-bottom: var(--sp-sm);
  }

  .page-header-meta {
    font-size: 0.875rem;
    color: var(--text-secondary);
  }

  /* Container Queries */
  @supports (container-type: inline-size) {
    .container-responsive {
      container-type: inline-size;
    }

    @container (min-width: 768px) {
      .container-md\:grid-cols-2 {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: var(--sp-xl);
      }
    }

    @container (min-width: 1024px) {
      .container-lg\:grid-cols-3 {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: var(--sp-xl);
      }
    }
  }

  /* Stat Bar (Horizontal, no cards) */
  .stat-bar {
    display: grid;
    grid-auto-flow: column;
    grid-auto-columns: 1fr;
    gap: var(--sp-xl);
    padding: var(--sp-xl);
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
  }

  @media (max-width: 768px) {
    .stat-bar {
      grid-auto-flow: row;
    }
  }

  .stat-item {
    display: flex;
    flex-direction: column;
    gap: var(--sp-sm);
  }

  .stat-label {
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-secondary);
  }

  .stat-value {
    font-family: var(--font-display);
    font-size: clamp(1.5rem, 3vw, 2.5rem);
    font-weight: 800;
    color: var(--text-primary);
    line-height: 1;
  }

  .stat-meta {
    font-size: 0.75rem;
    color: var(--text-muted);
  }

  /* Zone Block (Replacement for cards) */
  .zone {
    padding: var(--sp-xl);
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
  }

  .zone-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: var(--sp-lg);
    padding-bottom: var(--sp-lg);
    border-bottom: 1px solid var(--border-color);
  }

  .zone-title {
    font-size: 1rem;
    font-weight: 700;
    color: var(--text-primary);
  }

  .zone-content {
    display: flex;
    flex-direction: column;
    gap: var(--sp-lg);
  }

  /* Empty State */
  .empty-state {
    padding: var(--sp-3xl) var(--sp-xl);
    text-align: center;
  }

  .empty-state-icon {
    font-size: 3rem;
    margin-bottom: var(--sp-lg);
    opacity: 0.5;
  }

  .empty-state-title {
    font-size: 1.25rem;
    font-weight: 700;
    margin-bottom: var(--sp-sm);
  }

  .empty-state-text {
    color: var(--text-secondary);
    margin-bottom: var(--sp-lg);
  }
}
```

### Step 3: Commit navigation styles

Run:
```bash
git add app/assets/stylesheets/components/navigation.css app/assets/stylesheets/components/utilities.css
git commit -m "feat: add navigation and global utility styles with 37signals aesthetic"
```

---

## Task 3: Create Dashboard Styles & Redesign Dashboard View

**Files:**
- Create: `app/assets/stylesheets/components/dashboard.css`
- Modify: `app/views/dashboard/index.html.erb`
- Delete: `app/views/dashboard/_stat_card.html.erb`

### Step 1: Create dashboard-specific styles

Create `app/assets/stylesheets/components/dashboard.css`:

```css
@layer components {
  /* Dashboard Grid */
  .dashboard-container {
    display: grid;
    gap: var(--sp-2xl);
  }

  /* Hero Section */
  .dashboard-hero {
    display: grid;
    grid-template-columns: 1fr auto;
    gap: var(--sp-2xl);
    align-items: start;
  }

  @media (max-width: 768px) {
    .dashboard-hero {
      grid-template-columns: 1fr;
    }
  }

  .dashboard-hero-copy h1 {
    margin-bottom: var(--sp-md);
  }

  .dashboard-hero-desc {
    font-size: 1.125rem;
    color: var(--text-secondary);
    line-height: 1.6;
    max-width: 45ch;
  }

  .dashboard-hero-aside {
    padding: var(--sp-lg);
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    text-align: right;
    white-space: nowrap;
  }

  .dashboard-hero-status {
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-secondary);
    margin-bottom: var(--sp-sm);
  }

  .dashboard-hero-indicator {
    display: inline-flex;
    align-items: center;
    gap: var(--sp-sm);
    font-size: 0.875rem;
    font-weight: 600;
  }

  .dashboard-hero-dot {
    width: 0.5rem;
    height: 0.5rem;
    border-radius: 50%;
    background: var(--danger);
  }

  .dashboard-hero-dot.online {
    background: var(--success);
  }

  .dashboard-hero-timestamp {
    display: block;
    font-size: 0.75rem;
    color: var(--text-secondary);
    margin-top: var(--sp-sm);
  }

  /* Metrics Row */
  .dashboard-metrics {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: var(--sp-lg);
  }

  .metric-zone {
    padding: var(--sp-lg);
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
  }

  .metric-label {
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-secondary);
    margin-bottom: var(--sp-sm);
  }

  .metric-value {
    font-family: var(--font-display);
    font-size: 2rem;
    font-weight: 800;
    color: var(--text-primary);
    line-height: 1;
    margin-bottom: var(--sp-sm);
  }

  .metric-detail {
    font-size: 0.875rem;
    color: var(--text-secondary);
  }

  /* Content Zones */
  .dashboard-zones {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: var(--sp-2xl);
  }

  .content-zone {
    display: flex;
    flex-direction: column;
  }

  .content-zone-title {
    font-family: var(--font-display);
    font-size: 1.5rem;
    font-weight: 700;
    margin-bottom: var(--sp-lg);
    padding-bottom: var(--sp-lg);
    border-bottom: 2px solid var(--gold);
  }

  .content-zone-body {
    display: flex;
    flex-direction: column;
    gap: var(--sp-lg);
  }

  /* Info Row */
  .info-row {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: var(--sp-lg);
    padding: var(--sp-lg);
    background: var(--bg-surface);
    border-radius: 0.375rem;
  }

  .info-row-label {
    font-weight: 600;
    color: var(--text-primary);
    white-space: nowrap;
  }

  .info-row-value {
    color: var(--text-secondary);
  }
}
```

### Step 2: Read current dashboard view

Read `/var/home/kdlocpanda/second_brain/Resources/virtualization/docker/37signals/pocs/rccremote-docker/app/views/dashboard/index.html.erb`

### Step 3: Redesign dashboard view

Modify `app/views/dashboard/index.html.erb`:

```erb
<div class="dashboard-container">
  <!-- Hero Section -->
  <div class="dashboard-hero">
    <div class="dashboard-hero-copy">
      <h1>Runtime overview</h1>
      <p class="dashboard-hero-desc">Keep workspace definitions, catalog snapshots, and import intake aligned with the live RCC runtime.</p>
    </div>
    <div class="dashboard-hero-aside">
      <div class="dashboard-hero-status">RCC Status</div>
      <div class="dashboard-hero-indicator">
        <span class="dashboard-hero-dot <%= @runtime_status == 'online' ? 'online' : '' %>"></span>
        <span><%= @runtime_status&.upcase || 'OFFLINE' %></span>
      </div>
      <time class="dashboard-hero-timestamp">
        Snapshot updated <%= @snapshot_timestamp %>
      </time>
    </div>
  </div>

  <!-- Quick Stats -->
  <div class="stat-bar">
    <div class="stat-item">
      <div class="stat-label">Workspace(s)</div>
      <div class="stat-value"><%= @workspace_count %></div>
    </div>
    <div class="stat-item">
      <div class="stat-label">Catalog Snapshot(s)</div>
      <div class="stat-value"><%= @catalog_count %></div>
    </div>
    <div class="stat-item">
      <div class="stat-label">Import Bundle(s)</div>
      <div class="stat-value"><%= @import_count %></div>
    </div>
    <div class="stat-item">
      <div class="stat-label">Holotree Space(s)</div>
      <div class="stat-value"><%= @holotree_count %></div>
    </div>
  </div>

  <!-- Key Metrics Grid -->
  <div class="dashboard-metrics">
    <div class="metric-zone">
      <div class="metric-label">RCC Remote</div>
      <div class="metric-value"><%= @rcc_status %></div>
      <div class="metric-detail">Execution mode: <%= @execution_mode %></div>
    </div>
    <div class="metric-zone">
      <div class="metric-label">RCC Version</div>
      <div class="metric-value"><%= @rcc_version || 'unknown' %></div>
      <div class="metric-detail"><%= @binary_status %></div>
    </div>
    <div class="metric-zone">
      <div class="metric-label">Config Profile</div>
      <div class="metric-value"><%= @config_profile %></div>
      <div class="metric-detail"><%= @config_details %></div>
    </div>
    <div class="metric-zone">
      <div class="metric-label">Catalog Footprint</div>
      <div class="metric-value"><%= number_to_human_size(@catalog_size) %></div>
      <div class="metric-detail"><%= @blueprint_count %> active blueprint(s)</div>
    </div>
  </div>

  <!-- Content Zones -->
  <div class="dashboard-zones">
    <!-- Operator Cadence -->
    <div class="content-zone">
      <h2 class="content-zone-title">Operator cadence</h2>
      <div class="content-zone-body">
        <p class="text-sm text-muted">The three surfaces that usually move together during an RCC change window.</p>
        <div class="info-row">
          <div class="info-row-label">1</div>
          <div>
            <div class="info-row-value" style="font-weight: 600;">Stage workspaces</div>
            <div class="info-row-value text-sm"><%= @staged_workspace_count %> workspace(s) are ready for file review, YAML edits, or bundle staging.</div>
            <% if @staged_workspace_count > 0 %>
              <%= link_to "OPEN WORKSPACES", robots_path, class: "text-sm" %>
            <% end %>
          </div>
        </div>
      </div>
    </div>

    <!-- RCC Telemetry -->
    <div class="content-zone">
      <h2 class="content-zone-title">RCC telemetry</h2>
      <div class="content-zone-body">
        <p class="text-sm text-muted">Live runtime fields pulled from the control plane.</p>
        <div class="info-row">
          <div class="info-row-label">Mode</div>
          <div class="info-row-value"><%= @execution_mode %></div>
        </div>
        <div class="info-row">
          <div class="info-row-label">Space</div>
          <div class="info-row-value"><%= @most_used_space || 'n/a' %></div>
        </div>
        <div class="info-row">
          <div class="info-row-label">Use Count</div>
          <div class="info-row-value"><%= @use_count %></div>
        </div>
        <div class="info-row">
          <div class="info-row-label">Last Used</div>
          <div class="info-row-value"><%= @last_used || 'never' %></div>
        </div>
      </div>
    </div>
  </div>
</div>
```

### Step 4: Commit dashboard redesign

Run:
```bash
git add app/assets/stylesheets/components/dashboard.css app/views/dashboard/index.html.erb
git commit -m "feat: redesign dashboard with typography-first layout, no cards"
```

---

## Task 4: Create Workspaces Styles & Redesign Workspaces Views

**Files:**
- Create: `app/assets/stylesheets/components/workspaces.css`
- Modify: `app/views/robots/index.html.erb`
- Modify: `app/views/robots/show.html.erb`
- Delete: `app/views/robots/_robot.html.erb` (replace inline)

### Step 1: Create workspaces styles

Create `app/assets/stylesheets/components/workspaces.css`:

```css
@layer components {
  /* Workspace List */
  .workspace-list {
    display: grid;
    gap: var(--sp-lg);
  }

  .workspace-row {
    display: grid;
    grid-template-columns: 1fr auto auto;
    gap: var(--sp-lg);
    align-items: center;
    padding: var(--sp-lg);
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    transition: all 150ms ease;
  }

  .workspace-row:hover {
    background: var(--bg-raised);
    border-color: var(--gold);
  }

  .workspace-name {
    font-family: var(--font-display);
    font-size: 1.125rem;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: var(--sp-xs);
  }

  .workspace-meta {
    font-size: 0.875rem;
    color: var(--text-secondary);
  }

  .workspace-status {
    display: flex;
    align-items: center;
    gap: var(--sp-sm);
    padding: var(--sp-sm) var(--sp-lg);
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: 0.375rem;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .workspace-actions {
    display: flex;
    gap: var(--sp-sm);
  }

  .workspace-action-btn {
    padding: var(--sp-sm) var(--sp-lg);
    background: transparent;
    border: 1px solid var(--border-color);
    border-radius: 0.375rem;
    color: var(--text-primary);
    font-size: 0.875rem;
    font-weight: 500;
    transition: all 150ms ease;
  }

  .workspace-action-btn:hover {
    background: var(--gold);
    border-color: var(--gold);
    color: var(--ink);
  }

  /* Workspace Detail */
  .workspace-detail {
    display: grid;
    grid-template-columns: 1fr 350px;
    gap: var(--sp-2xl);
  }

  @media (max-width: 1024px) {
    .workspace-detail {
      grid-template-columns: 1fr;
    }
  }

  .workspace-detail-main {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2xl);
  }

  .workspace-detail-sidebar {
    display: flex;
    flex-direction: column;
    gap: var(--sp-lg);
    height: fit-content;
    position: sticky;
    top: calc(var(--sp-lg) + 4rem);
  }

  /* File Browser */
  .file-list {
    display: flex;
    flex-direction: column;
    gap: var(--sp-sm);
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    overflow: hidden;
  }

  .file-item {
    display: grid;
    grid-template-columns: auto 1fr auto;
    gap: var(--sp-md);
    align-items: center;
    padding: var(--sp-md) var(--sp-lg);
    background: var(--bg-surface);
    border-bottom: 1px solid var(--border-color);
    transition: all 150ms ease;
  }

  .file-item:last-child {
    border-bottom: none;
  }

  .file-item:hover {
    background: var(--bg-raised);
  }

  .file-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2rem;
    height: 2rem;
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: 0.375rem;
    font-size: 0.875rem;
    color: var(--text-secondary);
  }

  .file-info {
    display: flex;
    flex-direction: column;
    gap: var(--sp-xs);
  }

  .file-name {
    font-weight: 600;
    color: var(--text-primary);
  }

  .file-meta {
    font-size: 0.75rem;
    color: var(--text-secondary);
  }

  .file-action {
    padding: var(--sp-sm) var(--sp-md);
    background: transparent;
    border: 1px solid var(--border-color);
    border-radius: 0.25rem;
    color: var(--text-primary);
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    transition: all 150ms ease;
  }

  .file-action:hover {
    background: var(--gold);
    border-color: var(--gold);
    color: var(--ink);
  }

  /* Sidebar Boxes */
  .sidebar-box {
    padding: var(--sp-lg);
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
  }

  .sidebar-box-title {
    font-family: var(--font-display);
    font-size: 1rem;
    font-weight: 700;
    margin-bottom: var(--sp-md);
    padding-bottom: var(--sp-md);
    border-bottom: 1px solid var(--border-color);
  }

  .sidebar-box-content {
    display: flex;
    flex-direction: column;
    gap: var(--sp-sm);
  }

  .sidebar-row {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: var(--sp-sm);
  }

  .sidebar-row-label {
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-secondary);
  }

  .sidebar-row-value {
    font-size: 0.875rem;
    color: var(--text-primary);
    font-weight: 500;
  }
}
```

### Step 2: Read robots index view

Read `/var/home/kdlocpanda/second_brain/Resources/virtualization/docker/37signals/pocs/rccremote-docker/app/views/robots/index.html.erb`

### Step 3: Read robots show view

Read `/var/home/kdlocpanda/second_brain/Resources/virtualization/docker/37signals/pocs/rccremote-docker/app/views/robots/show.html.erb`

### Step 4: Read robots partial

Read `/var/home/kdlocpanda/second_brain/Resources/virtualization/docker/37signals/pocs/rccremote-docker/app/views/robots/_robot.html.erb`

### Step 5: Redesign workspaces index

Modify `app/views/robots/index.html.erb` - replace with typography-first list layout (specific content based on reading the file)

### Step 6: Redesign workspaces show

Modify `app/views/robots/show.html.erb` - create detail view with sidebar (specific content based on reading the file)

### Step 7: Commit workspaces redesign

Run:
```bash
git add app/assets/stylesheets/components/workspaces.css app/views/robots/
git commit -m "feat: redesign workspaces views with file-browser aesthetic, no cards"
```

---

## Task 5: Add Animations & View Transitions

**Files:**
- Create: `app/assets/stylesheets/animations.css`
- Create: `app/javascript/controllers/transitions_controller.js`
- Modify: `app/views/layouts/application.html.erb`

### Step 1: Create animations

Create `app/assets/stylesheets/animations.css`:

```css
@layer utilities {
  /* View Transitions Support */
  @supports (view-transition-name: root) {
    html {
      view-transition-name: root;
    }
  }

  /* Smooth Page Transitions */
  ::view-transition-old(root) {
    animation: fade-out 300ms ease-out forwards;
  }

  ::view-transition-new(root) {
    animation: fade-in 300ms ease-in forwards;
  }

  @keyframes fade-out {
    from {
      opacity: 1;
    }
    to {
      opacity: 0;
    }
  }

  @keyframes fade-in {
    from {
      opacity: 0;
    }
    to {
      opacity: 1;
    }
  }

  /* Micro-interactions */
  button, a, input {
    transition: all 150ms cubic-bezier(0.4, 0, 0.2, 1);
  }

  /* Skeleton Loading */
  @keyframes shimmer {
    0% {
      background-position: -1000px 0;
    }
    100% {
      background-position: 1000px 0;
    }
  }

  .skeleton {
    background: linear-gradient(
      90deg,
      var(--bg-surface) 25%,
      rgba(255, 211, 61, 0.05) 50%,
      var(--bg-surface) 75%
    );
    background-size: 1000px 100%;
    animation: shimmer 2s infinite;
  }
}
```

### Step 2: Create transitions controller

Create `app/javascript/controllers/transitions_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Listen for Turbo navigation
    document.addEventListener("turbo:click", this.prepareTransition.bind(this))
  }

  prepareTransition(event) {
    // Support for View Transitions API
    if (!document.startViewTransition) {
      return
    }

    // Start transition before navigation
    event.preventDefault()

    const href = event.target.closest("a")?.href
    if (!href) return

    document.startViewTransition(() => {
      return fetch(href)
        .then(response => response.text())
        .then(html => {
          const parser = new DOMParser()
          const doc = parser.parseFromString(html, 'text/html')
          document.documentElement.replaceWith(doc.documentElement)
        })
    })
  }
}
```

### Step 3: Commit animations

Run:
```bash
git add app/assets/stylesheets/animations.css app/javascript/controllers/transitions_controller.js
git commit -m "feat: add View Transitions API support and micro-interactions"
```

---

## Task 6: Remove Card Components & Remaining Views

**Files:**
- Delete: `app/views/shared/_stat_card.html.erb`
- Modify: `app/views/catalogs/index.html.erb`
- Modify: `app/views/hololib_zips/index.html.erb`
- Create: `app/assets/stylesheets/components/forms.css`

### Step 1: Delete stat card partial

Run:
```bash
rm app/views/dashboard/_stat_card.html.erb
```

### Step 2: Create forms styles

Create `app/assets/stylesheets/components/forms.css`:

```css
@layer components {
  /* Form */
  form {
    display: flex;
    flex-direction: column;
    gap: var(--sp-lg);
  }

  /* Form Group */
  .form-group {
    display: flex;
    flex-direction: column;
    gap: var(--sp-sm);
  }

  label {
    font-weight: 600;
    font-size: 0.875rem;
    color: var(--text-primary);
  }

  /* Input/Textarea */
  input, textarea, select {
    padding: var(--sp-md) var(--sp-lg);
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    color: var(--text-primary);
    font-size: 1rem;
    transition: all 150ms ease;
  }

  input:focus, textarea:focus, select:focus {
    outline: none;
    border-color: var(--gold);
    box-shadow: 0 0 0 3px rgba(255, 211, 61, 0.1);
  }

  input::placeholder, textarea::placeholder {
    color: var(--text-muted);
  }

  /* Button */
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: var(--sp-sm);
    padding: var(--sp-md) var(--sp-lg);
    background: var(--gold);
    border: none;
    border-radius: 0.5rem;
    color: var(--ink);
    font-weight: 600;
    font-size: 0.875rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    transition: all 150ms ease;
    cursor: pointer;
  }

  .btn:hover {
    background: var(--gold-muted);
    transform: translateY(-2px);
    box-shadow: 0 8px 16px rgba(255, 211, 61, 0.2);
  }

  .btn:active {
    transform: translateY(0);
  }

  .btn-secondary {
    background: transparent;
    border: 1px solid var(--border-color);
    color: var(--text-primary);
  }

  .btn-secondary:hover {
    background: var(--bg-surface);
    border-color: var(--gold);
    color: var(--text-primary);
    box-shadow: none;
  }
}
```

### Step 3: Redesign catalogs index

Modify `app/views/catalogs/index.html.erb` - create list layout (specific content based on reading file)

### Step 4: Redesign bundles index

Modify `app/views/hololib_zips/index.html.erb` - create list layout (specific content based on reading file)

### Step 5: Commit remaining views

Run:
```bash
git add app/views/catalogs/ app/views/hololib_zips/ app/assets/stylesheets/components/forms.css
git commit -m "feat: redesign catalogs and bundles views, remove all card components"
git rm app/views/dashboard/_stat_card.html.erb
git commit -m "chore: remove legacy stat card component"
```

---

## Task 7: Testing & Final Polish

### Step 1: Test all views

Run:
```bash
# Start Rails server
rails s

# Visit each route in browser:
# http://localhost:3000/                  (dashboard)
# http://localhost:3000/robots            (workspaces)
# http://localhost:3000/catalogs          (catalogs)
# http://localhost:3000/hololib_zips      (bundles)

# Test Omakase menu: Press J or Cmd+J
# Test theme toggle: Go to Omakase, toggle theme
# Test responsive: Resize browser to mobile width
```

### Step 2: Verify no cards remain

Run:
```bash
grep -r "card" app/views/ --include="*.erb" | grep -v "catalog_row\|_zip" || echo "✓ No card classes found"
```

### Step 3: Check CSS is loading

Open browser DevTools → Elements tab, verify:
- Design tokens applied (check colors in computed styles)
- No Tailwind classes remaining
- CSS cascade layers working

### Step 4: Test keyboard navigation

- Press J to open Omakase
- Use arrow keys to navigate
- Press Enter to select
- Press Esc to close
- Press number shortcuts (1-7)

### Step 5: Final commit

Run:
```bash
git add .
git commit -m "feat: complete redesign - typography-first, zero cards, 37signals aesthetic"
```

---

## Success Criteria

- ✅ Zero nested card components in any view
- ✅ All views use typography-first hierarchy
- ✅ Dashboard features horizontal stat bar
- ✅ Workspaces use file-browser aesthetic
- ✅ Omakase menu functional and enhanced
- ✅ Responsive on mobile (container queries)
- ✅ Dark/light theme working
- ✅ Page load under 1s
- ✅ Keyboard navigation throughout
- ✅ Feels like 37signals built it in 2024