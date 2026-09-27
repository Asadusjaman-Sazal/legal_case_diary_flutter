---
name: Justice Ledger
colors:
  # ---- Surfaces -----------------------------------------------------------
  # background is the app scaffold (`AppColors.background`), surface is the
  # white card / app-bar surface (`AppColors.surface`).
  background: '#f8fafc'
  on-background: '#191c1e'
  surface: '#ffffff'
  on-surface: '#191c1e'
  on-surface-variant: '#45464d'
  surface-dim: '#d8dadc'
  surface-bright: '#f7f9fb'
  surface-variant: '#f1f5f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f6'
  surface-container: '#eceef0'
  surface-container-high: '#e6e8ea'
  surface-container-highest: '#e0e3e5'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f3'
  surface-tint: 'transparent'
  outline: '#76777d'
  outline-variant: '#c6c6cd'
  card-border: '#e2e8f0'
  # ---- Brand / ink --------------------------------------------------------
  # Primary is the ink near-black text/header colour; Secondary is the single
  # unified active black; Tertiary is the muted metadata grey.
  primary: '#0f172a'
  on-primary: '#ffffff'
  primary-container: '#131b2e'
  on-primary-container: '#7c839b'
  inverse-primary: '#c6c6cd'
  secondary: '#000000'
  on-secondary: '#ffffff'
  secondary-container: '#000000'
  on-secondary-container: '#fefcff'
  tertiary: '#64748b'
  on-tertiary: '#ffffff'
  tertiary-container: '#0b1c30'
  on-tertiary-container: '#75859d'
  # ---- Semantic -----------------------------------------------------------
  error: '#dc2626'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  success: '#059669'
  court-notice: '#dc2626'
  status-active: '#059669'
  ink-dark: '#020617'
  # ---- Fixed / tonal tints ------------------------------------------------
  # These names survive from the blue era but now carry neutral greys, so no
  # chip, badge or selection tint is ever blue.
  primary-fixed: '#e6e8ea'
  primary-fixed-dim: '#c6c6cd'
  on-primary-fixed: '#131b2e'
  on-primary-fixed-variant: '#45464d'
  secondary-fixed: '#e6e8ea'
  secondary-fixed-dim: '#c6c6cd'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#45464d'
  tertiary-fixed: '#eceef0'
  tertiary-fixed-dim: '#c6c6cd'
  on-tertiary-fixed: '#131b2e'
  on-tertiary-fixed-variant: '#45464d'
  # ---- Overlays -----------------------------------------------------------
  # 0x8A000000 and 0x0D000000 expressed as CSS rgba().
  overlay-54: 'rgba(0, 0, 0, 0.54)'
  secondary-hover: 'rgba(0, 0, 0, 0.05)'
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
  # Bengali is unaffected by letter case and always uses Tiro Bangla at 1.5x
  # line height, so Bengali roles carry no letterSpacing override.
  bengali-title-md:
    fontFamily: Tiro Bangla
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 1.5
  bengali-body-lg:
    fontFamily: Tiro Bangla
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 1.5
  bengali-body-md:
    fontFamily: Tiro Bangla
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 1.5
  bengali-body-sm:
    fontFamily: Tiro Bangla
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 1.5
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  2xl: 1rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  xxl: 48px
  xxxl: 64px
  edge-margin: 16px
  gutter: 12px
  list-item: 12px
  card-padding: 16px
---

## Brand & Style

This design system is tailored for the legal profession in Bangladesh, balancing the rigorous demands of legal administrative work with a premium, modern digital experience. The brand personality is **authoritative, organized, and reliable**, designed to instill confidence in lawyers managing high-stakes case diaries.

The visual style is **Corporate / Modern** with a strong emphasis on information density and legibility. It uses a structured grid, purposeful whitespace and a high-contrast palette so that complex legal data stays scannable under pressure. While inspired by Material 3, the system introduces a bespoke "legal premium" feel through refined typography and an **Ink and Parchment** tonal approach—deep ink text on near-white parchment, with **no colour accent at all** for active states.

The UI targets a professional audience that values efficiency and data integrity. Every interaction is intentional, minimising cognitive load for users who frequently navigate dense lists of case numbers, dates and court details. It is **mobile-first**: every layout is designed for a phone-width viewport and nothing optimises for tablet or desktop yet.

## Colors

The palette is built on **ink, parchment and neutral greys**; there is no accent hue.

- **Primary (#0F172A):** The "Ink". Used for headers, app-bar titles, primary text and brand surfaces.
- **Secondary (#000000):** The single **unified active black**. Every active, selected or focused state—CTAs, selected navigation, language options, focus rings, text links—uses the same black as the buttons and the side menu. No screen marks a choice in colour.
- **Tertiary (#64748B):** Muted slate grey for secondary information, metadata and unfilled icons.
- **Background (#F8FAFC):** The "Parchment". The near-white scaffold that reduces eye strain and gives density a clean surface to sit on.
- **Surface (#FFFFFF):** Pure white for cards, app bars and sheets, separated from the parchment by a 1px `outline-variant` or `card-border` hairline.

Semantic colour is used sparingly and only for meaning: `error` / `court-notice` red (`#DC2626`) for overdue or urgent court dates, and `success` / `status-active` emerald (`#059669`) for disposed or synced states.

The `*-fixed` and `*-fixed-dim` tonal names survive from an earlier blue palette but now carry neutral greys (`#E6E8EA` / `#C6C6CD` / `#ECEEF0`), so chips, badges and selected rows tint grey, never blue.

## Typography

The typography system uses a tri-font approach to maximise legibility for specialised legal data.

1. **Manrope (Headlines):** Screen titles and major section headers. Its modern, geometric construction feels premium and professional.
2. **Inter (Body):** The primary workhorse font, chosen for legibility at small sizes in case lists and notes.
3. **IBM Plex Sans (Labels/Data):** Case numbers, court codes and dates. Its slightly industrial feel distinguishes "data" from "prose", helping lawyers spot case identifiers at a glance.

**Bengali** text uses **Tiro Bangla** at a 1.5x line height to accommodate the script's descenders. Bengali has no letter case, so Bengali roles carry no `letterSpacing`, and Title Case never applies.

### Casing

User-facing English is **Title Case** — the first letter of every word capital, the rest lowercase — written that way in the source, never produced by a render-time `toUpperCase()`. Proper nouns, acronyms, product names and the names of courts, offices and roles keep their capitals (WhatsApp, PDF, Google Drive, Legal Case Diary, Chief Judicial Magistrate).

## Layout & Spacing

The system is a **mobile-first fluid grid** built for a phone viewport (design width 390 px). There is no desktop or tablet breakpoint.

- **Vertical Rhythm:** Everything sits on a 4px baseline grid; every component height and vertical margin is a multiple of 4px.
- **Margins:** A standard 16px `edge-margin` on the screen sides, with a 12px `gutter` between adjacent columns.
- **Density:** High-density layouts are preferred. Lawyers need to see as many entries as possible without scrolling. Case lists use a condensed 12px `list-item` vertical padding; cards use 16px `card-padding`.
- **Data Strips:** The Daily Cause List and similar logs use condensed list rows rather than cards.

## Elevation & Depth

Hierarchy is achieved through **Tonal Layers** and **low-contrast outlines**, never heavy shadows. This keeps the flat, modern stationery feel.

- **Level 0 (Background):** `#F8FAFC` parchment, the scaffold.
- **Level 1 (Cards/Sheets):** White (`#FFFFFF`) with a 1px hairline (`#E2E8F0` card border, or `#C6C6CD` outline-variant). The primary container for case details.
- **Level 2 (Modals/Overlays):** The scrim is `rgba(0, 0, 0, 0.54)` (`overlay-54`); the sheet above it is white with at most a soft 8%-opacity ink shadow. **No `BackdropFilter`, no blur** is used anywhere.
- **Interactive states:** Hover and press tints are neutral — `rgba(0, 0, 0, 0.05)` (`secondary-hover`) — not a colour tint.

Avoid skeuomorphism; depth should feel structural, like stacked sheets of paper.

## Shapes

The shape language is **Soft (0.25rem / 4px)**.

Legal documents are traditionally rectangular and sharp; this system rounds just enough to modernise the look while keeping a serious, geometric structure.

- **Small components:** Checkboxes and small tags use `rounded-sm` (2px).
- **Standard components:** Buttons, input fields and cards use the base `rounded` (4px) — `AppSpacing.cardRadius`.
- **Large components:** Bottom sheets and dialogs use `rounded-lg` (8px) — `AppSpacing.sheetRadius` — on their top corners.
- **Pill / circle:** Status chips, avatars, icon buttons and the FAB use `rounded-full` (9999px); pills are never used for interactive buttons.

## Components

### Buttons
- **Filled (primary):** Black `#000000` background with white text. Bold, authoritative. The one button style for the main action.
- **Outlined:** Black `#000000` border and text on white. The secondary action ("Add Case", "Update").
- **Ghost / text:** No border, `tertiary` (`#64748B`) text. Used for "Cancel" or "Back".

### Input Fields
- "Filled" style with a `#F1F5F9` (`surface-variant`) background and a **bottom-only** border. The border thickens to 2px and turns black on focus. Labels use **IBM Plex Sans** to emphasise their role as data entry points.

### App Bars
- White `#FFFFFF` surface, 1px `outline-variant` bottom hairline, 0 elevation, ink (`#0F172A`) title in `headline-md`, ink icons, left-aligned title.

### Case Cards
- The core component. Displays Case Number (bold, IBM Plex Sans), Petitioner vs Respondent (body), and the Next Date highlighted with the black `secondary-container` surface. Action buttons inside cards are icon-only or text-link style to save space.

### Chips & Tags
- **Court Tags:** Small, subtle grey (`#E6E8EA`) background with ink text.
- **Status Tags:** Pill-shaped with low-saturation semantic colour (light-green background, dark-green text for "Disposed"; red for "Overdue").

### Lists
- **Divided lists** with 1px `card-border` (`#E2E8F0`) separators. Drop the separator for items grouped under one heading.

## Mockup Implementation

Every screen mockup under `mockup_html_screens/<screen>/code.html` is a **faithful rendering of the shipped Flutter screen** at a 390px-wide viewport. These rules keep all 30 files identical in structure and honest to the app.

### 1. Shared `<head>`

Copy this block verbatim into every `code.html`; change only `<title>`, and add the Bengali font link only when the screen has Bengali copy. Do not re-declare fonts, styles or a Tailwind config anywhere else.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta content="width=device-width, initial-scale=1.0" name="viewport">
<title>SCREEN NAME - Legal Case Diary</title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&family=IBM+Plex+Sans:wght@400;500;600;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<script id="tailwind-config">
  tailwind.config = {
    darkMode: "class",
    theme: {
      extend: {
        colors: {
          "background": "#f8fafc",
          "on-background": "#191c1e",
          "surface": "#ffffff",
          "on-surface": "#191c1e",
          "on-surface-variant": "#45464d",
          "surface-dim": "#d8dadc",
          "surface-bright": "#f7f9fb",
          "surface-variant": "#f1f5f9",
          "surface-container-lowest": "#ffffff",
          "surface-container-low": "#f2f4f6",
          "surface-container": "#eceef0",
          "surface-container-high": "#e6e8ea",
          "surface-container-highest": "#e0e3e5",
          "inverse-surface": "#2d3133",
          "inverse-on-surface": "#eff1f3",
          "surface-tint": "transparent",
          "outline": "#76777d",
          "outline-variant": "#c6c6cd",
          "card-border": "#e2e8f0",
          "primary": "#0f172a",
          "on-primary": "#ffffff",
          "primary-container": "#131b2e",
          "on-primary-container": "#7c839b",
          "inverse-primary": "#c6c6cd",
          "secondary": "#000000",
          "on-secondary": "#ffffff",
          "secondary-container": "#000000",
          "on-secondary-container": "#fefcff",
          "tertiary": "#64748b",
          "on-tertiary": "#ffffff",
          "tertiary-container": "#0b1c30",
          "on-tertiary-container": "#75859d",
          "error": "#dc2626",
          "on-error": "#ffffff",
          "error-container": "#ffdad6",
          "on-error-container": "#93000a",
          "success": "#059669",
          "court-notice": "#dc2626",
          "status-active": "#059669",
          "ink-dark": "#020617",
          "primary-fixed": "#e6e8ea",
          "primary-fixed-dim": "#c6c6cd",
          "on-primary-fixed": "#131b2e",
          "on-primary-fixed-variant": "#45464d",
          "secondary-fixed": "#e6e8ea",
          "secondary-fixed-dim": "#c6c6cd",
          "on-secondary-fixed": "#131b2e",
          "on-secondary-fixed-variant": "#45464d",
          "tertiary-fixed": "#eceef0",
          "tertiary-fixed-dim": "#c6c6cd",
          "on-tertiary-fixed": "#131b2e",
          "on-tertiary-fixed-variant": "#45464d",
          "overlay-54": "rgba(0, 0, 0, 0.54)",
          "secondary-hover": "rgba(0, 0, 0, 0.05)"
        },
        borderRadius: {
          "sm": "2px",
          "DEFAULT": "4px",
          "md": "6px",
          "lg": "8px",
          "xl": "12px",
          "2xl": "16px",
          "full": "9999px"
        },
        spacing: {
          "unit": "4px",
          "xs": "4px",
          "sm": "8px",
          "md": "16px",
          "lg": "24px",
          "xl": "32px",
          "xxl": "48px",
          "xxxl": "64px",
          "edge-margin": "16px",
          "gutter": "12px",
          "list-item": "12px",
          "card-padding": "16px"
        },
        fontFamily: {
          "headline-lg": ["Manrope"],
          "headline-md": ["Manrope"],
          "title-lg": ["Manrope"],
          "title-md": ["Inter"],
          "body-lg": ["Inter"],
          "body-md": ["Inter"],
          "body-sm": ["Inter"],
          "label-lg": ["IBM Plex Sans"],
          "label-md": ["IBM Plex Sans"],
          "case-number": ["IBM Plex Sans"],
          "bengali-title-md": ["Tiro Bangla"],
          "bengali-body-lg": ["Tiro Bangla"],
          "bengali-body-md": ["Tiro Bangla"],
          "bengali-body-sm": ["Tiro Bangla"]
        },
        fontSize: {
          "headline-lg": ["30px", { "lineHeight": "38px", "letterSpacing": "-0.02em", "fontWeight": "700" }],
          "headline-md": ["24px", { "lineHeight": "32px", "fontWeight": "600" }],
          "title-lg": ["20px", { "lineHeight": "28px", "fontWeight": "600" }],
          "title-md": ["16px", { "lineHeight": "24px", "fontWeight": "600" }],
          "body-lg": ["16px", { "lineHeight": "24px", "fontWeight": "400" }],
          "body-md": ["14px", { "lineHeight": "20px", "fontWeight": "400" }],
          "body-sm": ["12px", { "lineHeight": "16px", "fontWeight": "400" }],
          "label-lg": ["14px", { "lineHeight": "20px", "letterSpacing": "0.1px", "fontWeight": "500" }],
          "label-md": ["12px", { "lineHeight": "16px", "letterSpacing": "0.5px", "fontWeight": "500" }],
          "case-number": ["14px", { "lineHeight": "20px", "letterSpacing": "0.2px", "fontWeight": "700" }],
          "bengali-title-md": ["16px", { "lineHeight": "1.5", "fontWeight": "600" }],
          "bengali-body-lg": ["16px", { "lineHeight": "1.5", "fontWeight": "400" }],
          "bengali-body-md": ["14px", { "lineHeight": "1.5", "fontWeight": "400" }],
          "bengali-body-sm": ["12px", { "lineHeight": "1.5", "fontWeight": "400" }]
        }
      }
    }
  }
</script>
<style>
  body { background-color: #f8fafc; }
</style>
</head>
```

### 2. Class → token mapping

The Tailwind class names above are the app's token names, so a screen is written with the same vocabulary the Dart uses.

| Rendered app thing | Classes |
| --- | --- |
| Scaffold background | `bg-background` |
| App bar / header | `bg-surface border-b border-outline-variant` |
| Card | `bg-surface border border-card-border rounded card-padding` |
| Ink title / body text | `text-primary` |
| Muted metadata | `text-tertiary` or `text-on-surface-variant` |
| Unified active state, links, focus ring | `secondary` (`#000000`) |
| Selected-row / hover tint | `bg-secondary-hover` |
| Disposed / in-sync | `text-status-active` |
| Overdue / urgent | `text-court-notice` |
| Scrim | `bg-overlay-54` |

### 3. Body shell rules

- The `<body>` is `bg-background text-on-surface font-body-md` unless the screen's own design doc says otherwise.
- Remove the per-file `body { background-color: … }` override — the shared `<style>` sets `#f8fafc`, and the app has no dark theme, so every `dark:` variant in old markup is dead code and should be deleted.
- Screen content is centred with `max-w-lg mx-auto w-full` and `px-edge-margin`, matching the app's 390px design width.
- The app bars are 56–64px tall (`h-16` for most screens); the title is `font-headline-md text-headline-md font-bold text-primary`, left-aligned after the leading icon.
- Include the mockup's own `<title>` and, where the screen is reachable from Settings, the same back-chevron leading button as the app.
