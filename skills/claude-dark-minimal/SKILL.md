# Claude Dark Minimal — Design Style Guide

## Overview

Ultra-dark, minimal mobile UI design system inspired by Claude (Anthropic).
Prioritizes readability, breathing room, and subtle warmth through a single
accent color. **No gradients, no borders, no visual noise.** Every pixel
earns its place.

## Core Principles

1. **Dark-first** — near-black backgrounds (#0D0D0D), neutral gray surfaces.
2. **Flat** — zero elevation, no shadows, no borders. Separation through
   color contrast only.
3. **Single accent** — one warm color for interactive highlights; everything
   else is monochrome gray.
4. **Generous spacing** — 16-24 dp padding, 8-12 dp gaps. Content breathes.
5. **Subtle motion** — 200-350 ms easeOutCubic, fade + slight translate.
   No infinite loops in production UI.
6. **Typography hierarchy** — Inter / system sans-serif. Headings 600-700 w,
   negative letter-spacing. Body 400 w, 1.5 line-height.

---

## Color Palette

### Dark Mode (Primary)

| Token                | Value     | Usage                            |
|----------------------|-----------|----------------------------------|
| background           | `#0D0D0D` | Scaffold                         |
| surface              | `#1A1A1A` | Cards, modals, drawer             |
| surfaceContainerHigh | `#242424` | Input fields, composer background |
| surfaceContainerHighest | `#2E2E2E` | User message bubbles, hovered    |
| onSurface            | `#F5F5F5` | Primary text                     |
| onSurfaceVariant     | `#8E8E8E` | Placeholders, secondary text     |
| outlineVariant       | `#333333` | Subtle dividers (alpha 0.4)      |
| primary / accent     | `#D4854A` | Warm copper-amber seed            |
| onPrimary            | `#FFFFFF` | Text on accent                    |

### Light Mode (Secondary)

| Token                | Value     | Usage                            |
|----------------------|-----------|----------------------------------|
| background           | `#F5F5F5` | Scaffold                         |
| surface              | `#FFFFFF` | Cards, modals                     |
| surfaceContainerHigh | `#E8E8E8` | Input fields                      |
| onSurface            | `#1A1A1A` | Primary text                     |
| onSurfaceVariant     | `#757575` | Placeholders, secondary text     |

---

## Typography

| Role        | Size | Weight | Letter-spacing | Line-height |
|-------------|------|--------|----------------|-------------|
| Display     | 36sp | 500    | -0.2           | 1.22        |
| Headline    | 24sp | 600    | -0.1           | 1.33        |
| Title Large | 22sp | 600    | -0.3           | 1.27        |
| Title Medium| 16sp | 500    | 0.15           | 1.50        |
| Body Large  | 16sp | 400    | 0.5            | 1.50        |
| Body Medium | 14sp | 400    | 0.25           | 1.43        |
| Body Small  | 12sp | 400    | 0.4            | 1.33        |
| Label       | 14sp | 500    | 0.1            | 1.43        |

Font family: Inter (fallback: system sans-serif).
Code: monospace, 13.5 sp, surfaceContainerHighest background.

---

## Component Specifications

### Border Radius
- Cards, chips, buttons: **16 dp**
- Input fields, composer: **24 dp**
- Bottom sheet top corners: **28 dp**
- Icon buttons: **14 dp**
- FAB, scroll-to-bottom: **circle**

### Elevation
- **Zero everywhere.** No BoxShadow, no Card elevation.
- Depth is communicated through background-color contrast only.

### Borders
- **None.** No OutlineInputBorder, no BorderSide.
- Separation between regions (e.g., composer top) uses a 1 px
  divider with `outlineVariant` at 40 % alpha.

### Padding & Spacing
- Screen edge padding: **16 dp** horizontal
- Card internal padding: **16 h × 12 v**
- Between sibling elements: **8-12 dp**
- Section gaps: **24-32 dp**
- Input text padding: **20 h × 14 v**

---

## Specific Components

### AppBar
- Transparent background (surface).
- Zero elevation, zero scrolledUnderElevation.
- Title: logo (32 dp) + app name, left-aligned, 16 dp spacing.
- Actions: icon buttons, 14 dp radius, no background.

### Composer (Input Bar)
- Single-row container with top divider (1 px, outlineVariant 40 %).
- TextField: surfaceContainerHigh background, 24 dp radius, no border.
- Placeholder: onSurfaceVariant 70 %, 15 sp.
- Send button: 48 dp circle. Primary fill when active, surfaceContainerHigh
  when inactive. No gradient, no shadow. Icon: 22 dp.

### Message Bubbles
- **User**: surfaceContainerHighest, 16 dp radius, 16 h × 12 v padding.
- **AI**: surfaceContainerHigh, 16 dp radius, 16 h × 12 v padding.
- Asymmetric bottom corners: 6 dp on the "tail" side.
- No avatar per message.
- Copy button: 12 sp, onSurfaceVariant, icon + text, 4 dp padding.
- Code blocks: surfaceContainerHighest background, 14 dp radius.

### Welcome Screen
- Centered layout, vertical column.
- Logo: 64-72 dp, solid primary circle, no glow, no pulse.
- Title: headlineMedium, onSurface (white), plain text (no gradient).
- Subtitle: bodyLarge, onSurfaceVariant, 1.6 line-height.
- Suggestion chips: flat surface cards, 16 dp radius, icon + text.
  No gradient icon backgrounds, no arrow.

### Suggestion Chips
- Surface: surfaceContainerHigh.
- Radius: 16 dp.
- Icon: 20 dp, primary color, NO gradient circle background.
- Text: 14.5 sp, weight 500, onSurface.
- Layout: vertical list, 10 dp gap.
- Stagger animation: fade-only, 150 ms interval.

### Drawer
- Surface background (same as main).
- Left border radius: 28 dp.
- Width: 280 dp.
- New-chat button: filled, primary, 16 dp radius.
- Conversation tile: 14 dp radius, transparent / surfaceContainerLow
  for selected state. No heavy highlight.
- Footer: simple text, no decorative dots.

### Typing Indicator
- Three dots, 8 dp each, 3 dp horizontal padding.
- Color: onSurfaceVariant with animated alpha (0.4-1.0).
- Container: surfaceContainerHigh, 16 dp radius top, 6 dp bottom-right.
- No per-message avatar.

### Scroll-to-Bottom FAB
- 44 dp circle, surfaceContainerHigh, zero elevation.
- Positioned: bottom 76 dp, right 16 dp.
- Fade + scale animation (200 ms, easeOutCubic).

### Bottom Sheet
- Surface: surfaceContainerLow.
- Top radius: 28 dp.
- Animation: fade + slide-up, 200 ms.

### SnackBar
- Floating behavior.
- 16 dp radius.
- SurfaceContainerHigh background.

### Toggle / Switch
- Track: surfaceContainerHighest (off) / primary (on).
- Thumb: white / onPrimary.
- Animation: 200 ms.

---

## Animation Guidelines

| Type      | Duration | Curve          | Usage                     |
|-----------|----------|----------------|---------------------------|
| Fade      | 200 ms   | easeOutCubic   | Modals, FAB, chips        |
| Slide+Fade| 350 ms   | easeOutCubic   | Message appearance        |
| Scale     | 200 ms   | easeOutCubic   | Button press feedback     |
| Layout    | 300 ms   | easeInOutCubic | Theme switch, screen trans |

- **No infinite/repeat animations** in visible production UI.
- `TweenAnimationBuilder` for one-shot (message appear).
- `AnimationController` only for typing dots (functional).

---

## Branding Rules

1. **No gradient text.** Titles are plain onSurface color.
2. **No gradient backgrounds** on any interactive element.
3. **No glow / box-shadow** around logo or buttons.
4. **No decorative shapes** — every element is functional.
5. Logo: solid primary circle with a single icon. Static (or at most a
   very subtle 1.02× scale pulse).
6. Accent color appears ONLY on: send button (active), toggle (on),
   selected drawer item underline, link text, typing dots.