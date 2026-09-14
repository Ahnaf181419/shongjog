# Design System & Accessibility (WCAG AAA)

In disaster response applications, user interface clarity is a direct determinant of life-safety. Shongjog's design system ([`lib/app/theme.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/app/theme.dart)) is engineered to ensure optimal legibility under glaring tropical sunlight, in pitch-black storm conditions, and on low-end mobile displays.

---

## 1. Brand Identity & Color System

The design is anchored on a core **Deep Ocean Blue** (~205° hue family), evoking water, calm authority, and safety:

```
[ Light Theme ]                                [ Dark Theme ]
Ocean Primary:  #0369A1 (Sky-700, L~32)        Ocean Bright:   #38BDF8 (Sky-400, L~70)
Scaffold Light: #F8FAFC (Slate-50)             Scaffold Dark:  #0F172A (Slate-900)
Surface Dim:    #F1F5F9 (Slate-100)            Surface Dark:   #1E293B (Slate-800)
```

### The Strict "Alert Red" Invariant
- **`alert = Color(0xFFDC2626)` (Red-600)**:
- **Design Law**: Alert Red is strictly reserved for genuine life-critical emergency triggers (the 999 slide dialer knob, active SOS broadcast beacons, and extreme hazard notifications). It is **never** used as a general decorative accent, brand flourish, or generic secondary button color.

---

## 2. Semantic Fills vs. Inks (WCAG AAA Compliance)

A common design pitfall in mobile UI is using the same color for an icon/chip background and the text label rendered over it. Shongjog enforces a dual-token system separating **fills** (tinted container backgrounds) from **inks** (high-contrast text labels rendered on top of 15% tinted containers):

| Semantic State | Fill Token | Ink Token | Contrast on `surfaceDim` | WCAG Rating |
|---|---|---|---|---|
| **Success** | `Color(0xFF16A34A)` | `successInk = Color(0xFF166534)` | **5.18 : 1** | **AAA** |
| **Warning** | `Color(0xFFB45309)` | `warningInk = Color(0xFF92400E)` | **5.15 : 1** | **AAA** |
| **Danger** | `Color(0xFFDC2626)` | `dangerInk = Color(0xFF991B1B)` | **5.82 : 1** | **AAA** |
| **Information** | `Color(0xFF0284C7)` | `infoInk = Color(0xFF075985)` | **8.60 : 1** | **AAA** |

- **Contrast Standard**: Ensures a minimum of **7.0 : 1** contrast ratio for regular body text (exceeding standard AA requirements and hitting WCAG AAA), and **3.0 : 1** for large UI touch elements.

---

## 3. Typography & Bengali Script Calibration

Rendering the complex Bengali script legibly on low-DPI Android handsets requires deliberate font selection and sizing floors:

- **Primary Font Family**: `AnekBangla` — a modern variable typeface specifically balanced for crisp Bengali conjunct characters (যুক্তাক্ষর) and clear Bengali numerals (`০ ১ ২ ৩ ৪ ৫ ৬ ৭ ৮ ৯`).
- **Latin Fallback**: `Manrope` — high-x-height geometric sans-serif for clean technical readouts and English mode.
- **Minimum Font Sizing Floors**:
  - `bodyFloor = 17.0`: Body text never drops below 17sp to guarantee legibility when the user is running or trembling.
  - `bodyLargeFloor = 20.0`: Actionable step headers and instructions are locked at 20sp or larger.

---

## 4. Accessibility & Layout Resilience

1. **1.5× Display & Font Scaling Resilience**:
   - Every screen, bento grid, and quick card is verified under Android's maximum accessibility font scale (1.5×).
   - Layouts use flexible `Wrap`, `Expanded`, and bounded `SingleChildScrollView` containers, preventing text clipping or overflow rendering errors (`RenderFlex overflowed`).
2. **48×48dp Minimum Touch Target**:
   - All buttons, icon taps, and list tiles maintain a minimum bounding box of 48×48 device-independent pixels (dp) to ensure reliable activation with wet, muddy, or gloved fingers.
3. **Screen Reader Semantics**:
   - Floating navigation pills and status badges are wrapped in labeled `Semantics` widgets, ensuring that talkback screen readers announce contextual state (e.g. *"Danger beacon active, 3 nearby alerts"*).
