# Design system (source of truth)

## Brand

- Display name: **WorkInsight Tracker**
- Mark: geometric diamond logo (`assets/branding/workinsight_mark.svg`)
- In-app: mark + stacked text (`WorkInsight` / `Tracker`)
- OS chrome (Windows title bar / taskbar): mark-only icon
- Technical id: `witrack` / `com.witrack.desktop`
- Tagline: Work smarter. Track clearly.
- Palette reference: Work Insights portal (deep navy + teal actions)

## Color tokens

### Dark (default)

| Token | Hex | Role |
|---|---|---|
| `bg.primary` | `#071521` | App canvas |
| `bg.secondary` | `#0C1E2E` | Sidebar / chrome |
| `surface` | `#122A3D` | Cards / panels |
| `accent.primary` | `#14B8A6` | Primary actions, active nav |
| `accent.secondary` | `#A78BFA` | Secondary charts / accents |
| `highlight` | `#14B8A6` | Selection accents |
| `text.primary` | `#F8FAFC` | Titles / body |
| `text.secondary` | `#94A3B8` | Muted labels |
| `danger` | `#E11D48` | Destructive |
| `warning` | `#F59E0B` | Warning |
| `success` | `#16A34A` | Success |
| `border` | `#1E3A4F` | Hairlines |
| `nav.active` | `#134E4A` | Sidebar selected row |
| `logo` | `#FFFFFF` | Mark glyph on dark |

### Light

| Token | Hex |
|---|---|
| `bg.primary` | `#F3F6F8` |
| `bg.secondary` | `#E8EEF2` |
| `surface` | `#FFFFFF` |
| `accent.primary` | `#0F766E` |
| `accent.secondary` | `#7C3AED` |
| `highlight` | `#0F766E` |
| `text.primary` | `#0B1A24` |
| `text.secondary` | `#475569` |
| `border` | `#D0DAE3` |
| `nav.active` | `#DCF5F2` |
| `logo` | `#0F766E` (teal-green mark) |

## Typography

- Display / titles: **Plus Jakarta Sans** (semi-bold / bold)
- Body: **Plus Jakarta Sans** (regular / medium)
- Bundled locally in `assets/fonts/` — no runtime network font fetch
- Avoid Inter, Roboto, Arial, and default system-only stacks for brand surfaces

## Spacing & radius

- Base grid: 4px
- Common: 8 / 12 / 16 / 24 / 32
- Radius: 8 (controls), 12 (panels), 16 (hero cards)

## Motion

Subtle, 150–250ms ease; prefer opacity/slide. No decorative noise. Avoid full-screen rebuild flicker on timer ticks.

## Theme switching

- Default: **dark** (`ThemeMode.dark` via `themeModeProvider`)
- User can switch to light; keep using existing `ThemeModeController` — do not fork a second theme system
- Tokens live in `lib/core/theme/witrack_colors.dart`; ThemeData mapping in `witrack_theme.dart`

## Implementation

Dart tokens: `lib/core/theme/witrack_colors.dart`, `witrack_theme.dart`, `witrack_typography.dart`.  
Brand widgets: `lib/core/widgets/witrack_mark.dart`, `brand_lockup.dart`.
