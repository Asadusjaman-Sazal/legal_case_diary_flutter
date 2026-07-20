---
name: Justice Ledger
colors:
  surface: '#f7f9fb'
  surface-dim: '#d8dadc'
  surface-bright: '#f7f9fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f6'
  surface-container: '#eceef0'
  surface-container-high: '#e6e8ea'
  surface-container-highest: '#e0e3e5'
  on-surface: '#191c1e'
  on-surface-variant: '#45464d'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f3'
  outline: '#76777d'
  outline-variant: '#c6c6cd'
  surface-tint: '#565e74'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#131b2e'
  on-primary-container: '#7c839b'
  inverse-primary: '#bec6e0'
  secondary: '#0051d5'
  on-secondary: '#ffffff'
  secondary-container: '#316bf3'
  on-secondary-container: '#fefcff'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#0b1c30'
  on-tertiary-container: '#75859d'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dae2fd'
  primary-fixed-dim: '#bec6e0'
  on-primary-fixed: '#131b2e'
  on-primary-fixed-variant: '#3f465c'
  secondary-fixed: '#dbe1ff'
  secondary-fixed-dim: '#b4c5ff'
  on-secondary-fixed: '#00174b'
  on-secondary-fixed-variant: '#003ea8'
  tertiary-fixed: '#d3e4fe'
  tertiary-fixed-dim: '#b7c8e1'
  on-tertiary-fixed: '#0b1c30'
  on-tertiary-fixed-variant: '#38485d'
  background: '#f7f9fb'
  on-background: '#191c1e'
  surface-variant: '#F1F5F9'
  court-notice: '#DC2626'
  status-active: '#059669'
  ink-dark: '#020617'
typography:
  headline-lg:
    fontFamily: Manrope
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-lg:
    fontFamily: Manrope
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: IBM Plex Sans
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-md:
    fontFamily: IBM Plex Sans
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
  case-number:
    fontFamily: IBM Plex Sans
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.2px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  edge-margin: 16px
  gutter: 12px
---

## Brand & Style

This design system is tailored for the legal profession in Bangladesh, balancing the rigorous demands of legal administrative work with a premium, modern digital experience. The brand personality is **authoritative, organized, and reliable**, designed to instill confidence in lawyers managing high-stakes case diaries.

The visual style is **Corporate / Modern** with a strong emphasis on information density and legibility. It utilizes a structured grid, purposeful whitespace, and a high-contrast palette to ensure that complex legal data remains scannable under pressure. While inspired by Material 3, the system introduces a bespoke "legal premium" feel through refined typography and a sophisticated "Ink and Parchment" tonal approach—replacing standard grays with deep, ink-like blues and crisp, clean whites.

The UI targets a professional audience that values efficiency and data integrity. Every interaction is designed to be intentional, minimizing cognitive load for users who frequently navigate dense lists of case numbers, dates, and court details.

## Colors

The palette is built on a foundation of **deep ink blues** and **professional grays**. 

- **Primary (#0F172A):** Represents the "Ink"—used for critical headers, brand elements, and primary text to establish authority.
- **Secondary (#2563EB):** The "Action" color. Used for primary call-to-actions, active navigation states, and highlighting interactive elements.
- **Tertiary (#64748B):** Used for secondary information, icons, and metadata to create visual hierarchy.
- **Neutral (#F8FAFC):** The "Parchment" equivalent. A near-white background that reduces eye strain compared to pure white, providing a clean surface for dense data.

Semantic colors are used sparingly: a sharp red for urgent court deadlines or missed dates, and a refined emerald green for disposed or successful case statuses.

## Typography

The typography system uses a tri-font approach to maximize legibility for specialized legal data. 

1. **Manrope (Headlines):** Used for screen titles and major section headers. Its modern, geometric construction feels premium and professional.
2. **Inter (Body):** The primary workhorse font. Chosen for its exceptional legibility at small sizes in case lists and notes.
3. **IBM Plex Sans (Labels/Data):** A technical font used for case numbers, court codes, and dates. Its slightly industrial feel distinguishes "data" from "prose," helping lawyers quickly identify case identifiers.

For **Bengali text**, ensure the system falls back to a high-quality local serif like *Tiro Bangla* or a clean sans-serif like *Hind Siliguri* to maintain the professional tone. Line heights are slightly increased (1.5x) for body text to accommodate Bengali script descenders.

## Layout & Spacing

This design system employs a **Fluid Grid** for mobile and a **12-column Fixed Grid** for web views (max-width 1200px). 

- **Vertical Rhythm:** Built on a 4px baseline grid. All component heights and vertical margins are multiples of 4px.
- **Mobile Layout:** 16px side margins are standard. Case list items use a condensed 12px vertical padding to maximize the number of visible rows.
- **Web Scaling:** On desktop, the side navigation becomes persistent. Case details expand into a multi-column view to utilize the horizontal real estate, avoiding overly long line lengths for legal notes.
- **Density:** High-density layouts are preferred. Lawyers need to see as many entries as possible without scrolling. Use "Data Strips" (condensed list items) for the Daily Cause List.

## Elevation & Depth

Visual hierarchy is achieved through **Tonal Layers** and **Low-Contrast Outlines** rather than heavy shadows. This maintains a flat, modern aesthetic that feels like high-end stationery.

- **Level 0 (Background):** `#F8FAFC` (Neutral).
- **Level 1 (Cards/Sheets):** White (`#FFFFFF`) with a subtle 1px border (`#E2E8F0`). This is the primary container for case details.
- **Level 2 (Modals/Overlays):** White with a soft, highly diffused ambient shadow (8% opacity Primary color) to indicate temporary focus.
- **Interactive States:** Hover or press states on list items use a subtle tint of the Secondary color (`#2563EB` at 5% opacity).

Avoid skeuomorphism; depth should feel structural, like stacked sheets of paper.

## Shapes

The shape language is **Soft (0.25rem / 4px)**. 

Legal documents are traditionally rectangular and sharp. This system uses subtle rounding to modernize the look while retaining a serious, geometric structure. 

- **Small Components:** Checkboxes and small tags use `rounded-sm` (2px).
- **Standard Components:** Buttons, Input Fields, and Cards use the base `rounded` (4px).
- **Large Components:** Bottom sheets and dialogs use `rounded-lg` (8px) on top corners only.

Pill shapes are strictly avoided except for "Status Chips" to distinguish them from interactive buttons.

## Components

### Buttons
- **Primary:** Filled `#0F172A` with White text. Bold, authoritative.
- **Secondary:** Outlined with `#2563EB` border and text. Used for "Add Case" or "Update."
- **Tertiary/Ghost:** No border, `#64748B` text. Used for "Cancel" or "Back."

### Input Fields
- Use "Filled" style with a `#F1F5F9` background and a bottom-only border that thickens on focus. Labels should be in **IBM Plex Sans** to emphasize their role as data entry points.

### Case Cards
- The core component. Must display: Case Number (Bold), Petitioner vs Respondent (Body), and Next Date (Highlighted with a secondary tint background). 
- Action buttons within cards (e.g., "Call Client") should be icon-only or text-link style to save space.

### Chips & Tags
- **Court Tags:** Small, subtle gray background with `#0F172A` text.
- **Status Tags:** Pill-shaped with low-saturation semantic colors (e.g., light green background with dark green text for "Disposed").

### Lists
- Use "Divided Lists" with 1px `#E2E8F0` separators. Remove separators for grouped items (e.g., cases under the same court).