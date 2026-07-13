# Shongjog — UX/UI Design

> **Internal team-facing document.** Design principles, personas, user flows, dual-mode
> visual system, accessibility, per-screen specs, interaction patterns, premium UX layer,
> and implementation handoff for a Bangla-first, low-literacy, crisis-context Flutter app.

This document applies the `impeccable` skill's principles — high contrast, no decorative
slop, every element earns its place — to a Flutter mobile surface for users in distress.
The bar is not "beautiful"; the bar is **trustworthy and usable under stress by people who
cannot read well, may be wet, may be shaking, and may have one hand free — and that bar,
when hit precisely, is what makes the app feel premium.**

Companion docs: product scope in `docs/prd.md`; technical architecture in
`docs/architecture.md`; build tasks in `docs/implementation-plan.md`; team division in
`docs/team.md`.

---

## 1. Design Principles

1. **Calm in crisis.** The palette is low-stimulation: deep teal, sand, ink. No red
   except for emergencies. Nothing flashes. Motion is restrained — fades and small
   shifts, never bounce or elastic.
2. **Low-literacy first.** Bangla is the default and primary script. Type is large.
   Sentences in UI copy are short. Icons carry meaning independently of text. Every text
   answer has a speak-aloud button.
3. **Fail-safe defaults.** Static quick cards render before the model is ready. If the
   model fails, the app is still useful. No screen is ever empty.
4. **One decision at a time.** No settings menu in the critical path. The user lands on
   chat, sees the mic, and can act. Secondary affordances (cards, shelter, dial) are one
   tap away but never compete with the primary action.
5. **Truthful, attributable, bounded.** Answers come from a sourced corpus; if the app
   doesn't know, it says so. Never perform confidence the model doesn't have.
6. **Premium is restraint, not ornament.** A premium crisis app is not one with more
   decoration — it is one where every element looks intentional, every state is designed,
   and the user never feels the app is unfinished, broken, or generic. Craft you only
   notice on the second look.

---

## 2. Anti-patterns we refuse (mobile crisis context)

These are the equivalents of the `impeccable` "absolute bans," adapted to a mobile
disaster app. Match-and-refuse: if you are about to ship any of these, rewrite the
element.

- **Decorative red.** Red is reserved for emergency-only actions (999 dial, SOS, snakebite
  do-not cards). Never for accents, headers, or chart fills.
- **Auto-playing audio.** TTS only fires on user tap or after a confirmed answer render
  AND the user has enabled auto-read. Never on screen open.
- **Countdown timers on critical actions.** A user in distress must never feel rushed by
  the UI. (Timers may exist in code for performance budgets, never shown to users.)
- **Tiny tap targets.** The minimum is 48×48dp. The mic button is 64dp. Users may be wet,
  cold, or wearing gloves.
- **Cropped Bangla glyphs.** Some Android fonts clip Bangla conjuncts (যুক্তাক্ষর). Test
  every screen with real Bangla strings, not placeholder Latin.
- **Empty states that blame the user.** If the model isn't ready, the UI says "AI
  প্রস্তুত হচ্ছে..." and surfaces quick cards — never "error" or a blank screen.
- **Dense menus.** No hamburger menu, no settings drawer in the critical path. Three
  entry points max on any screen: mic / input, cards, emergency.
- **English in user-facing copy.** Pure Bangla on the user surface. Universal acronyms
  (ORS, SMS, GPS, SOS) stay; everything else translates. (See §14, plain-language lock.)
- **Lottie / canned illustration libraries.** No praying-hands animations, no heart
  bursts, no generic medical illustrations. Custom marks only, drawn to match the brand
  stroke weight.
- **Identical card-icon grids.** The 6 quick cards are NOT six identical tiles with
  icon + title + body. Each card has a distinct shape: different leading glyph, different
  severity tint hint, different internal layout. Six cards look six different ways.
- **Fake-precise numbers.** "৯৯৯ কল উত্তরের সময়: ৪৫ সেকেন্ড" is a lie. Write "৯৯৯" and
  stop. Numbers in user UI are either real (from the corpus / device) or absent.
- **Skeuomorphic hardware.** No phone illustration that looks like a phone. No pill
  bottle icons with gloss. The user knows what these things are; use flat brand glyphs.
- **Side-stripe borders.** No `border-left` accent stripes on cards or callouts. Full
  borders, background tints, or nothing. (`impeccable` absolute ban.)
- **Gradient text.** Never `background-clip: text` with a gradient. Solid color only;
  emphasis via weight or size. (`impeccable` absolute ban.)
- **Glassmorphism as default.** No decorative `BackdropFilter` blurs. Rare and purposeful
  (the bottom sheet for cards-as-anchor) or nothing.
- **Tiny uppercase tracked eyebrows.** No "ABOUT" / "EMERGENCY" small-caps kickers above
  every section header. One deliberate kicker as brand voice is fine; on every section it
  is AI grammar.

---

## 3. Personas

Derived from `docs/prd.md` §1. Used to ground every design decision.

### P1 — Rahima, 38, rural mother
- **Context:** Two children. Floodwater entered the home 4 hours ago. Youngest has
  diarrhea. Phone at 30% battery, no signal, no power.
- **Literacy:** Reads simple Bangla slowly; cannot type Bangla.
- **Goal:** "What do I do for my child's diarrhea, right now, with what I have."
- **Critical affordance:** Voice input + spoken answer. Must work in airplane mode.

### P2 — Abdul, 67, elderly farmer
- **Context:** Cyclone warning issued. Cannot walk far. Lives 2km from the nearest
  shelter but doesn't know which one.
- **Literacy:** Minimal; relies on voice.
- **Goal:** "Where is the nearest shelter, and how do I call for help."
- **Critical affordance:** Big mic, big "dial 999", GPS-driven nearest shelter.

### P3 — Sumi, 24, community volunteer
- **Context:** First responder in her village. Uses the app to look up ORS recipe and
  snakebite do/don'ts while assisting neighbors.
- **Literacy:** High; comfortable with both Bangla and English.
- **Goal:** "Fast reference cards I can trust, even if the model is slow."
- **Critical affordance:** Static quick cards that work without the model loaded.

---

## 4. User Flows

### Flow 1 — First launch → model ready (premium first-load sequence)
1. App opens. Splash renders: darkBody background, white "স" glyph breathing once (1.2s),
   "শঙ্গ্যোগ" in Display 28sp below.
2. Fade to chat screen. Empty state: 3 suggestion pills (ORS / shelter / snakebite).
3. Model loads in background. AppBar subtitle shows "মডেল প্রস্তুত হচ্ছে... (৪৫%)".
4. On completion: subtitle updates to "AI প্রস্তুত". Mic button becomes active.
5. Quick-cards icon in the AppBar is available throughout — no dependency on the model.

### Flow 2 — Voice query → grounded spoken answer (mic-first input)
1. User taps mic (64dp). Mic fills alertRed, subtle 1.4s opacity pulse; "শুনছি..." label
   appears. Haptic: `lightImpact`.
2. Partial transcript appears in the input field as Vosk decodes.
3. User stops speaking (or taps mic again). Query submits.
4. User bubble slides in from below (200ms ease-out fade). Haptic: `selectionClick`.
5. Assistant bubble appears with "ভাবছি..." + animated dot-clock.
6. Answer renders token-by-token (streaming) or in one block (fallback).
7. Below the answer: "পড়ুন" button fades in. TTS plays in `bn-BD` at 0.9x rate.
   Haptic on answer-ready: `mediumImpact`. Optional sound: water-drop knock (300ms).
8. Footer chip on every critical answer: "জরুরি হলে ৯৯৯ এ কল করুন".

### Flow 3 — Quick card lookup (no model, card-as-anchor)
1. User taps the cards icon in the AppBar (always present on chat screen).
2. Quick cards slide up as a half-screen bottom sheet — not a full route change.
3. User taps a card → expands inline with numbered Bangla steps.
4. Selecting a card drops a seed phrase into the input ("ORS তৈরি করতে..."). User
   confirms or edits. Bridges cards and chat without modal interruption.
5. No model call. Works in airplane mode even if model failed to load.

### Flow 4 — Find nearest shelter
1. From chat answer bubble action row, user taps "নিকটস্থ আশ্রয়কেন্দ্র দেখান".
2. GPS resolves (with permission prompt if first time).
3. Map screen opens, centered on user location. User-location dot pulses at 1.4s.
4. Top 3 nearest shelters rendered as shield markers in calmTeal, sorted by distance.
5. Tapping a marker opens a bottom sheet with name (Bangla) + capacity (if known) +
   distance in km.

### Flow 5 — Emergency dial + SOS SMS (slide-to-confirm)
1. User taps phone icon in the AppBar (always visible on chat screen).
2. Full-screen takeover: "জরুরি কল" at top, large ৯৯৯ in alertRed center.
3. Bottom: slide-to-confirm pad (track 56dp, knob 56dp circle in alertRed). Bangla
   instruction: "কল করতে ডানে স্লাইড করুন". Cannot be triggered by accidental tap.
4. On full slide → haptic `heavyImpact` → `tel:999` opens system dialer.
5. Below the slider: secondary "পরিবর্তে SOS পাঠান" link in calmTeal — tappable,
   opens prefilled `sms:999?body=...` with location-encoded body.

### Flow 6 — Help (long-press affordance)
1. User long-presses (2s) the AppBar title on any screen.
2. Help sheet slides up: what is this app, who built it, how to use voice, what happens
   offline, the data sources. Single screen, plain Bangla.
3. Dismiss with tap-outside or system back.

---

## 5. Visual System

### 5.1 Color tokens (dual mode — light default, dark on system preference)

**Strategy (per `impeccable`):** Committed — the calm teal carries the brand identity at
~30% of the visible surface (AppBar + primary CTA + selected state); neutrals carry ~70%
of the surface; alertRed is strictly emergency-only and never decorative.

**Light mode (default):**

| Token | Hex | Role | Contrast note |
|---|---|---|---|
| `paperWhite` | `#FAF7F0` | Body background | base surface |
| `sand` | `#F4ECD8` | Secondary surface — card bg, input fill | on `inkBlack`: 11.6:1 (AAA) |
| `inkBlack` | `#1A1A1A` | Primary text | on `paperWhite`: 15:1 (AAA) |
| `calmTeal` | `#0E5E6F` | Identity — AppBar, primary CTA, brand | on `paperWhite`: 7.4:1 (AAA) |
| `softTeal` | `#E8F0F2` | Muted surface — assistant chat bubble | on `inkBlack`: 12:1 (AAA) |
| `alertRed` | `#B23A48` | Emergency-only — dial, SOS, snakebite-don't | on `paperWhite`: 5.0:1 (AA+); large elements only |
| `onSurface` | `inkBlack` | Default text token on light surfaces | — |

**Dark mode (system preference):**

| Token | Hex | Role | Contrast note |
|---|---|---|---|
| `darkBody` | `#0A1922` | Body background (near-black, teal-tinted — never pure black) | base surface |
| `elevated` | `#112733` | Card / bubble elevated surface | on `warmOffWhite`: 13:1 (AAA) |
| `warmOffWhite` | `#F0EAE0` | Primary text on dark | on `darkBody`: 16:1 (AAA) |
| `calmTeal+` | `#4FB3C8` | Identity (brightened for dark contrast) | on `darkBody`: 8.5:1 (AAA) |
| `softTealDark` | `#1A3540` | Assistant chat bubble (dark variant) | on `warmOffWhite`: 11:1 (AAA) |
| `alertRed+` | `#E57180` | Emergency (brightened for dark contrast) | on `darkBody`: 5.2:1 (AA+); large elements only |
| `onSurface` | `warmOffWhite` | Default text token on dark surfaces | — |
| `mutedText` | `#A8B5BC` | Secondary text on dark (captions, subtitles) | on `darkBody`: 6.2:1 (AAA) |

**Verification rule (from `impeccable`):** body text ≥ 4.5:1, large text (≥18px or bold
≥14px) ≥ 3:1. We hit AAA on every primary text pairing in both modes. `alertRed` /
`alertRed+` is reserved for large icons and short labels, never body copy.

**Never use pure `#000000` or pure `#FFFFFF`.** Pure black kills depth on dark; pure
white is sterile and harsh on stressed eyes. Always the off-black / off-white tokens.

### 5.2 Type scale (Hind Siliguri, single family)

```
Family: Hind Siliguri (Google Fonts, OFL license)
  Light     300    captions (rare use)
  Regular   400    body default
  Medium    500    primary CTAs, body-large
  Semibold  600    AppBar title, card titles, display
```

| Role | Size | Weight | Line height | Letter spacing | Use |
|---|---|---|---|---|---|
| Display | 28sp | w600 | 1.3 | -0.01em | AppBar title, splash brand |
| Title | 22sp | w600 | 1.3 | 0 | Card titles, screen headers |
| Body | 17sp | w400 | 1.5 | 0 | All body text, chat, card steps |
| Body large | 20sp | w500 | 1.4 | 0 | Mic label, primary CTA labels |
| Caption | 14sp | w400 | 1.4 | 0 | Source attribution, distances, AppBar subtitle |

**Body floor is 17sp**, not the Material default 14sp — low-literacy users and stress
both demand larger type.

**Bangla rendering notes:**
- Line height 1.5 on body (Bangla ascenders/descenders need more vertical space than
  Latin; Material's default 1.4 clips conjuncts).
- Hind Siliguri has contemporary Bangla feel and good weight range. Conjuncts
  (যুক্তাক্ষর like ক্ষ, জ্ঞ, ণ্ড) render cleanly in most cuts; if Phase 5 reveals
  clipping on any screen, that screen overrides to Noto Serif Bengali (see §12 Bangla
  conjunct fallback).
- Bangla numerals (০-৯) are slightly heavier than Latin in Hind Siliguri. Accept the
  imbalance; do not mix scripts within a single phrase. Phase 5 QA verifies "৯৯৯" renders
  identically across mic label, card list, and footer chip.
- Numbers in user-facing copy: Bangla numerals (০-৯). Western digits only in internal
  logs and the debug overlay.

**Font fallback chain:** Hind Siliguri → Noto Sans Bengali → system Bengali →
Devanagari (last resort, degraded).

### 5.3 Spacing scale

4 / 8 / 12 / 16 / 24 / 32 / 48dp. Use 48dp only around the mic button and primary CTAs.

### 5.4 Radii

- Cards: 12dp
- Chat bubbles: 16dp
- Buttons: 12dp (filled), full-pill (mic FAB)
- Sheets: 20dp top corners
- Input fields: 12dp

**Shape consistency lock:** all surfaces use 12dp or 16dp corners; the mic FAB is the
only full-pill shape in the app. No mixing radii on the same screen unless there is a
documented rule.

### 5.5 Motion (tightened, premium-grade)

- **Default duration:** 180ms (tightened from 200ms — crisis apps feel faster, less
  perceived latency).
- **Easing:** `Curves.easeOutCubic` for entrances; never bounce, never elastic, never
  spring-with-overshoot.
- **Mic pulse:** 1.4s loop, opacity 0.4 → 1.0, only while actively listening. Stops the
  instant Vosk finalizes.
- **Ambient mic glow:** when ambient mic permission is granted and mic is idle, a slow
  3s opacity glow (0.7 → 1.0) signals "ready to listen." Subtle liveness without urgency.
- **TTS speaking indicator:** a thin horizontal bar at the bubble bottom, fades in when
  audio starts and out when it ends. No animation while idle.
- **Page transitions:** 240ms `fadeThrough` (Material 3 pattern) — never slide-from-right
  (too marketing-y for crisis context).
- **Chat bubble entrance:** slides in from below with 200ms ease-out fade; no
  rubber-band, no bounce on edges.
- **Streaming answer reveal:** tokens render in place at a paced 30fps insertion. A
  dot-clock in the bubble corner ("ভাবছি...") cycles until the first token arrives.
- **First-load sequence:** splash (1.2s) → animated "স" glyph breathing once → chat
  screen with AppBar subtitle "মডেল প্রস্তুত হচ্ছে...". Fade-out once ready, never a
  hard swap.
- **Reduced motion (mandatory):** respect `MediaQuery.disableAnimations`. Replace mic
  pulse with static "শুনছি..." label; replace ambient glow with static fill; replace TTS
  bar with crossfade; replace first-load animation with instant splash → chat.

---

## 6. Accessibility

| Concern | Rule |
|---|---|
| Tap target | Minimum 48×48dp; mic button 64×64dp |
| Contrast | AAA on all primary text in BOTH light and dark mode; `alertRed`/`alertRed+` only for large elements |
| Dark mode | `paperWhite`/`darkBody` contrast verified at 16:1; no pure black, no pure white |
| Bangla rendering | Test every screen with real Bangla (including যুক্তাক্ষর); ship Hind Siliguri; per-screen override to Noto Serif Bengali if clipping found |
| Font fallback | Hind Siliguri → Noto Sans Bengali → system Bengali → Devanagari (degraded) |
| Screen reader | `Semantics(label: ...)` on every icon button; chat bubbles read with the bank below |
| No critical timeouts | The user is never timed out of an action; only performance budgets exist in code |
| Color-only signaling | Never encode meaning in color alone — pair red with an icon (phone, shield, warning); pair offline-status with a texture (breathing dot) |
| One-handed use | Primary actions (mic, input, send) in the bottom third; emergency dial reachable from AppBar |
| Offline indicator | Persistent AppBar micro-status line (see §13-D); never red, never alarming |
| Focus order | Top-to-bottom, mic-first when chat is empty |
| Help affordance | Long-press (2s) AppBar title on any screen opens a one-page help sheet (see §14) |
| Auto-read toggle | Long-press chat title toggles "always speak aloud" for low-literacy / visually impaired users; persisted in `shared_preferences` |

**Screen reader announcement bank (every interactive element needs a label):**

| Element | `Semantics(label:)` |
|---|---|
| Chat user bubble | `আপনার বার্তা` |
| Chat assistant bubble | `সহকারীর বার্তা` |
| "পড়ুন" button | `উত্তর পড়ুন` |
| Mic button (idle) | `প্রশ্ন বলুন` |
| Mic button (listening) | `শুনছি, থামাতে আবার চাপুন` |
| Cards icon (AppBar) | `জরুরি সহায়তা কার্ড` |
| Phone icon (AppBar) | `জরুরি কল` |
| 999 footer chip | `জরুরি হলে ৯৯৯ এ কল করুন` |
| Suggestion pill | `<full pill text>` |
| Shelter marker | `<shelter name>, দূরত্ব <distance> কিমি` |

---

## 7. Screen Specs

Every screen below has a **"moment"** — exactly one element that is more crafted than the
rest. This is the premium-second-look detail. The rest of the screen follows the system.

### 7.1 Chat screen (primary)
- **AppBar:** teal background (light) / `darkBody` with `calmTeal+` accents (dark), title
  "সংযোগ — জরুরি সহায়তা". Right actions: cards icon, phone icon. No back button (home).
  Subtitle line below title (12sp, 70% opacity): persistent status ("অফলাইন" /
  "AI প্রস্তুত" / "জিপিএস নেই" / "মডেল প্রস্তুত হচ্ছে (৪৫%)").
- **Body:** `ListView` (reversed) of `MessageBubble`s. User bubbles right-aligned `calmTeal`
  with white text; assistant bubbles left-aligned `softTeal` (light) / `softTealDark` (dark)
  with `inkBlack` / `warmOffWhite` text. 24dp between bubbles (airy density). Each
  assistant bubble has a "পড়ুন" button.
- **Bottom:** `ChatInput` — 64dp mic FAB (left, full-pill), collapsed text pill (center,
  expands on long-press or chevron tap), "পাঠান" button (right, appears only when text
  field is expanded). Mic is primary; typing is secondary.
- **Empty state:** 3 suggestion pills (`ORS কীভাবে বানাবো?` / `নিকটস্থ আশ্রয়কেন্দ্র` /
  `সাপে কামড়ালে কী করবো?`), tappable, doubles as a soft tour.
- **Cold start:** if `_repo == null`, AppBar subtitle shows "মডেল প্রস্তুত হচ্ছে...";
  the "জরুরি কার্ড" link remains tappable so the user isn't blocked.
- **Returning user:** if `shared_preferences` has a prior conversation, restore it instead
  of showing suggestion pills.
- **Moment:** the mic button — soft emboss (1dp inner shadow), sand-colored bottom edge,
  subtle ambient glow when idle. The tactile anchor of the whole app.

### 7.2 Quick cards screen (card-as-anchor bottom sheet)
- **Trigger:** cards icon in chat AppBar. Slides up as a half-screen bottom sheet (20dp
  top corners), not a full route change.
- **Body:** `ListView.separated` of 6 `Card`s, each an `ExpansionTile` with a custom
  leading glyph (see §15), Bangla title, and numbered steps inside. 12dp between cards
  (compact density).
- **Six cards, six shapes:** ORS (water-drop glyph, calmTeal tint), water purification
  (filter glyph, sand tint), snakebite (snake glyph, alertRed do-not tint), severe
  diarrhea (warning glyph, calmTeal tint), cyclone shelter (shield glyph, calmTeal tint),
  bleeding control (cross glyph, alertRed do-not tint). No identical card-icon grid.
- **Numbered Bangla steps:** `১. পানি ফুটিয়ে ঠাণ্ডা করুন। ২. এক চা চামচ চিনি যোগ করুন।`
  Bangla numerals, danda (।) as terminator.
- **No model dependency.** Must render instantly even before `ModelManager` initializes.
- **Moment:** the ORS card — slightly larger leading glyph (32dp vs 28dp for others),
  signals "this is the most-used card, start here."

### 7.3 Shelter map screen
- **AppBar:** "নিকটস্থ আশ্রয়কেন্দ্র". Subtitle shows GPS status.
- **Body:** `FlutterMap`, centered on user GPS (or Bangladesh default 23.8, 90.4 if GPS
  denied — with a `Sand`-tinted disclaimer banner "জিপিএস নেই — সমগ্র বাংলাদেশ দেখানো
  হচ্ছে"). Shield markers in `calmTeal`. Tapping a marker opens a bottom sheet with name
  (Bangla), capacity, distance in km.
- **Offline tiles:** bundled MBTiles for the coastal belt. If missing, accept cached OSM
  tiles as fallback (clearly noted in the demo script).
- **Moment:** the user-location dot — pulses at 1.4s (opacity 0.6 → 1.0), `calmTeal` ring
  around `inkBlack` center. The one piece of liveliness on an otherwise static map.

### 7.4 Emergency action sheet (DEPRECATED — replaced by 7.5)
Kept for reference only. The modal "হ্যাঁ / না" confirmation is the **fallback** if
slide-to-confirm widget proves too costly in Phase 1.2. Default ship target is 7.5.

### 7.5 Emergency action sheet (slide-to-confirm — default)
- **Trigger:** phone icon in chat AppBar.
- **Full-screen takeover:** `darkBody` background (both modes — emergency context always
  dark for focus). Top: "জরুরি কল" in Display 28sp `warmOffWhite`. Center: large ৯৯৯
  in `alertRed+`, 96sp Semibold. Below: one-line instruction "ডানে স্লাইড করে কল
  শুরু করুন" in Caption 14sp `mutedText`.
- **Bottom:** slide-to-confirm pad. Track 56dp tall, full width minus 32dp margins,
  `elevated` background, 12dp radius. Knob: 56dp circle in `alertRed+`, white phone glyph
  centered. User drags knob fully right → on release at ≥90% track width, triggers
  `tel:999`. Haptic `heavyImpact` on confirm. If released < 90%, knob springs back
  (`easeOutCubic` 240ms).
- **Accessibility:** for `MediaQuery.disableAnimations` / screen reader users, the slider
  collapses to a large "কল করুন" button (fallback to the §7.4 modal pattern).
- **Below the slider:** secondary "পরিবর্তে SOS পাঠান" link in `calmTeal+`, tappable,
  opens prefilled `sms:999?body=...` with location-encoded body.
- **Top-left:** "বাতিল" (cancel) text button, returns to chat.
- **Moment:** the slide-to-confirm knob itself — the deliberate drag replaces accidental
  taps. The one interaction in the app that demands physical intention.

### 7.6 Emergency hub screen (Maruf's — navigation landing)
- **AppBar:** "শঙ্গ্যোগ" in Display 28sp. Right action: about/sources icon.
- **Body:** `ListView` with 16dp padding. Three 96dp-tall tiles, full-bleed `calmTeal`,
  12dp between. Each tile: 40dp white custom glyph at left, Bangla title (Body large 20sp
  Medium, white) + Bangla subtitle (Body 14sp Regular, 90% white), chevron-right at right.
  - Tile 1: "জরুরি সহায়তা কার্ড" → `/cards`. Subtitle: "ORS, পানি, সাপের কামড় — দ্রুত নির্দেশিকা".
  - Tile 2: "নিকটস্থ আশ্রয়কেন্দ্র" → `/shelter`. Subtitle: "জিপিএস থেকে নিকটস্থ সাইক্লোন শেল্টার".
  - Tile 3: "জরুরি কল (৯৯৯)" → triggers slide-to-confirm sheet. `alertRed` background
    instead of `calmTeal`. Subtitle: "এক ট্যাপে জরুরি সেবায় কল".
- **Optional 4th tile** (smaller, 64dp): "তথ্যসূত্র সম্পর্কে" → `/about`.
- **Moment:** Tile 1 (cards) gets a 1dp elevation that catches light differently —
  signals "this is the most common destination, start here."

### 7.7 About / sources page (Sehab's — static attribution)
- **AppBar:** "তথ্যসূত্র". Back arrow present.
- **Body:** `ListView`, 24dp padding (airy density). Top: 200dp header in `sand` (light) /
  `elevated` (dark) with brand mark "শঙ্গ্যোগ" in Display 28sp `calmTeal` + one-line
  tagline in Body 17sp.
- **Sources list:** 5 source cards, each a 1px-border surface (`calmTeal` at 30% opacity
  border) with a `verified` custom glyph in `calmTeal` leading, English name (Title 22sp
  Semibold) + Bangla name (Body 17sp Regular) stacked. 24dp between cards.
- **Bottom disclaimer:** "অ্যাপ কখনো রোগ নির্ণয় করে না বা ওষুধ দেয় না — শুধু সাধারণ
  সহায়তা দেয়। জরুরি হলে সর্বদা ৯৯৯ নম্বরে কল করুন বা নিকটস্থ হাসপাতালে যান।" in
  Body 17sp, full `inkBlack` / `warmOffWhite`.
- **Moment:** the 200dp header — the only branded visual moment in the app outside the
  splash. Quiet, confident, attributable.

### 7.8 App icon + splash
- **App icon:** flat `calmTeal` rounded square (matches AppBar color), centered white
  "স" glyph (Hind Siliguri Semibold, custom-kerned). No text on the icon other than the
  glyph. The "স" suggests "সংযোগ" (connection) and stands alone as a mark. PNG variants:
  48×48, 72×72, 96×96, 144×144, 192×192. Adaptive icon foreground = white "স" on
  transparent; background = `calmTeal`.
- **Splash:** `darkBody` background (cold-boot is always dark-themed on Android regardless
  of system pref), centered white "স" glyph (96dp) + "শঙ্গ্যোগ" in Display 28sp below.
  1.2s fade-in. The "স" breathes once (scale 1.0 → 1.05 → 1.0, 1.2s `easeOutCubic`) then
  fades to the chat screen.
- **Moment:** the breathing "স" — the app's first and last visual impression. Quiet,
  alive, intentional.

---

## 8. Microinteractions

Folded into §11 (interaction patterns) and §13 (premium UX details). Kept here as a quick
reference table.

| Trigger | Response |
|---|---|
| Mic tapped | Button fills `alertRed`, 1.4s opacity pulse; "শুনছি..." label; haptic `lightImpact` |
| Partial STT result | Transcript fills the input field live |
| Query submitted | User bubble slides in (200ms ease-out fade); haptic `selectionClick` |
| Answer streaming | Tokens append in place at 30fps; dot-clock "ভাবছি..." cycles until first token |
| Answer ready | "পড়ুন" button fades in; haptic `mediumImpact`; optional water-drop sound (300ms) |
| Low-confidence answer | Bubble dims to 88% opacity; "আমি নিশ্চিত নই" chip appears; 999 footer chip brightens |
| TTS playing | Soft bar under answer fades in; mic disabled to avoid feedback |
| GPS resolving | Map shows brief spinner centered on last known location; never a blank map |
| Card tapped (in sheet) | Card expands inline (ExpansionTile, 180ms); seed phrase drops into chat input |
| Slide-to-confirm dragged | Knob follows finger; haptic tick at 50% and 90%; spring-back if released early |
| Emergency confirmed | Haptic `heavyImpact`; brief 120ms screen flash in `alertRed+` at 10% opacity; dialer opens |
| Offline state | AppBar subtitle reads "অফলাইন"; subtle breathing dot (2s, opacity 0.5↔1.0) in `calmTeal` |
| No mic permission | Mic button shows diagonal-stripe shimmer; tap opens permission rationale sheet |
| No GPS | Thin amber underline below AppBar subtitle; map shows Bangladesh default + disclaimer |

---

## 9. Bangla Typography Notes

- **Font:** Hind Siliguri (Google Fonts, OFL). Single family, 4 weights (300/400/500/600).
  Bundled in `assets/fonts/` (4 `.ttf` files, ~600KB total).
- **Line height:** Bangla needs slightly more vertical space than Latin — `height: 1.5`
  on body text, not Material's default 1.4.
- **Conjuncts (যুক্তাক্ষর):** Hind Siliguri handles most cleanly. If Phase 5 reveals
  clipping on a specific screen, that screen overrides to Noto Serif Bengali (per §12
  Bangla conjunct fallback rule).
- **Numerals:** use Bangla numerals (০-৯) in ALL user-facing copy (যেমন "৯৯৯", "৩-৬ ধাপ",
  "৪৫%"). Use Western numerals only in internal logs and the debug overlay. Verify
  numeral weight consistency across screens in Phase 5 QA.
- **Punctuation:** danda (।) is the canonical full stop; keep it. Don't mix danda and
  Latin period in the same chunk. Question mark (? / ?) — Bangla uses ॥ for some
  contexts but ? is acceptable for UI questions.
- **Plain-language lock (see §14):** never use English medical/legal/technical terms in
  user copy. "Hydration" → "পানি ও লবণ"; "Symptom" → "লক্ষণ"; "Dehydration" →
  "পানিশূন্যতা". Universal acronyms (ORS, SMS, GPS, SOS) stay as-is.

---

## 10. Design QA Checklist (before demo)

- [ ] Every screen tested with real Bangla strings (no Latin placeholders).
- [ ] Every screen tested in BOTH light and dark mode on the demo device.
- [ ] Contrast verified on a real device outdoors (sunlight is a worst case).
- [ ] Mic button tappable with one thumb from either hand.
- [ ] 999 dial reachable in ≤ 2 taps from any screen.
- [ ] Slide-to-confirm dry-run: drag-release at 89% does NOT trigger; at 90% does.
- [ ] Quick cards render with the model fully unloaded (force-quit + relaunch).
- [ ] No animation exceeds 300ms; no bounce anywhere.
- [ ] TTS plays cleanly through the phone speaker (not just headphones).
- [ ] TTS voice name locked in code; documented in §15.
- [ ] Low-confidence canned response looks intentional, not broken.
- [ ] Bangla numerals (৯৯৯) render identically across mic, card, footer chip.
- [ ] Reduced-motion mode: every animation has a static fallback that still communicates
      state.
- [ ] Haptics verified on the demo device (not just emulator).
- [ ] App icon renders crisply at 48×48 (smallest variant).
- [ ] Splash breathing "স" completes in ≤ 1.2s and does not delay first paint.

---

## 11. Interaction Patterns (6 codified)

### 11.1 Slide-to-confirm for emergency actions
**Trigger:** dial 999 / send SOS. A horizontal track with a draggable knob. Cannot be
triggered by accidental tap. One-handed, deliberate. Bangla instruction: "ডানে স্লাইড
করে কল শুরু করুন". Accessibility fallback: large "কল করুন" button for screen-reader /
reduced-motion users.

### 11.2 Mic-first chat input
**Trigger:** chat input area. Mic is the primary surface (64dp FAB on the left). Text
input is collapsed to a 4dp-thin pill by default; long-press or chevron-tap expands it.
No accidental typing. When mic is listening, the input becomes a banner "শুনছি..."
without opening the keyboard. The "পাঠান" button appears only when the text field has
content.

### 11.3 Streaming answer reveal
**Trigger:** assistant response render. Tokens render in place via paced 30fps insertion.
A dot-clock "ভাবছি..." in the bubble corner cycles until the first token arrives, then
disappears. Tapping the bubble during streaming jumps to the full final state (no race
for the user). If streaming isn't available (fallback mode), the full block renders with
a 200ms fade-in.

### 11.4 Card-as-anchor in AppBar
**Trigger:** cards icon in chat AppBar (always present). Tapping opens quick cards as a
half-screen bottom sheet (20dp top corners), not a full route change. Selecting a card
drops a seed phrase into the input ("ORS তৈরি করতে..."), the user just confirms or
edits. Bridges cards and chat without modal interruption.

### 11.5 Confidence as opacity, not color
**Trigger:** low-confidence model response. A low-confidence answer dims to 88% opacity
and shows a small "আমি নিশ্চিত নই" chip. The 999 footer chip brightens to full opacity.
Calm, not alarming. No yellow anywhere — yellow conflicts with `sand` (`impeccable` rule).
Confidence is communicated through weight and presence, never through a new color.

### 11.6 Status as motion + texture
**Trigger:** any system state change (offline, no mic, no GPS, model loading). Offline →
small `calmTeal` dot with slow breathing pulse (2s, opacity 0.5↔1.0). No-mic →
diagonal-stripe shimmer on the mic button. No-GPS → thin amber underline below the AppBar
subtitle. Model loading → percentage in AppBar subtitle. Colorblind users get the same
message through motion and texture. The 999 chip never changes state — it is always
reachable, always alertRed, always primary.

---

## 12. System Consistency Locks

These locks are enforced in code review (PR review against this doc). Violating any lock
requires a documented justification in the PR description.

- **Theme lock:** once a screen renders in light or dark, it stays that way for the
  session. App follows system preference only; no mid-page flip, no in-app toggle. The
  only exception: the emergency action sheet (§7.5) is always `darkBody` regardless of
  system pref — emergency context demands focus.
- **Accent lock:** `calmTeal` / `calmTeal+` is the only accent. Every CTA, every selected
  state, every active icon uses one of the three teal variants (`calmTeal`, `softTeal`,
  `calmTeal+`). Red only for emergency. No other accent color anywhere.
- **Copy register lock:** user-facing copy is 100% Bangla. Brand name "Shongjog" appears
  once at app open (splash). "Bangla" / "Bangladesh" can appear in the about page and
  developer logs. No English in user UI except universal acronyms (ORS, SMS, GPS, SOS).
- **Motion lock:** no animation exceeds 240ms (except first-load splash at 1.2s); no
  bounce anywhere; no scroll-jacking; no parallax. Every animation has a reduced-motion
  fallback.
- **Z-index lock:** semantic scale only. sticky AppBar (1) > bottom input bar (2) >
  bottom sheet overlay (3) > modal dialog (4) > toast (5). No arbitrary `z-index: 999`.
- **Bangla conjunct fallback rule:** if any screen shows clipped যুক্তাক্ষর in Phase 5
  testing, the offending screen overrides its font to Noto Serif Bengali (bundled as
  `assets/fonts/NotoSerifBengali-Regular.ttf` + `-SemiBold.ttf`). This is a per-screen
  override, documented in the PR. Not a global swap.
- **Density lock:** chat 24dp between bubbles (airy); quick cards 12dp (compact); hub 16dp
  between tiles (spacious); about 24dp between cards (airy); shelter map no list spacing
  (map is full-bleed). One rhythm per screen type, no arbitrary spacing.
- **Shape lock:** all surfaces 12dp or 16dp corners; mic FAB is the only full-pill. No
  mixing radii on the same screen.

---

## 13. Premium UX Details (14 items, 4 groups)

These are the details that separate "competent crisis app" from "premium crisis app."
Each is small individually; together they create the second-look craft.

### A. Sensory (makes it feel alive, not generic)

**13.1 Haptic vocabulary.** 5 signatures, codified in `HapticService`:
| Event | Haptic | Flutter API |
|---|---|---|
| Mic press | `lightTap` | `HapticFeedback.lightImpact()` |
| Card open / selection | `mediumTap` | `HapticFeedback.selectionClick()` |
| Answer rendered | `success` | `HapticFeedback.mediumImpact()` |
| Low-confidence answer | `warn` | `HapticFeedback.heavyImpact()` (single) |
| Emergency confirmed | `strong` | `HapticFeedback.heavyImpact()` + `vibrate()` |

Haptics respect `MediaQuery.disableAnimations` — if reduced motion is on, haptics are
also suppressed (some users have sensory sensitivities that span both).

**13.2 Sound identity.** Two owned sounds, both optional (off by default if system ringer
is silent):
- **Shongjog chime:** 1.5s tone at app open (after splash, before chat). Bangla-tuned,
  gentle, not an alert. A soft two-note rise (like a singing bowl). File:
  `assets/sound/chime.wav` (placeholder — Ahnaf sources or synthesizes in Phase 5).
- **Answer-ready knock:** 300ms water-drop sound when an assistant answer finishes
  rendering. Replaces the default TTS enable beep. File: `assets/sound/knock.wav`.

Both gated by `shared_preferences` keys `sound_chime_enabled` (default true) and
`sound_knock_enabled` (default true), suppressed when `AudioManager` reports ringer
silent. No sound plays more than once per 5 seconds (debounce).

**13.3 Smooth scroll.** Chat uses `ScrollConfiguration` with a custom `BouncingScrollPhys`
replacement — no rubber-band, no bounce on edges. Chat bubble slide-in from below with
200ms ease-out fade. Scroll deceleration tuned to feel weighted, not flighty. Premium ≠
bouncy; premium = deliberate.

**13.4 Ambient motion.** Two ambient motions, both subtle:
- Mic button idle glow: 3s opacity cycle (0.7 → 1.0) when ambient mic permission is
  granted and mic is not actively listening. Signals "ready to listen" without urgency.
- First hub tile shimmer: while model is warming up, Tile 1 (cards) has a 4s diagonal
  shimmer sweep at 5% opacity. Disappears the moment the model is ready. Signals liveness.

### B. First impression (the first 5 seconds)

**13.5 First-load sequence.** Splash (1.2s, breathing "স") → fade to chat screen → empty
state with 3 suggestion pills → AppBar subtitle "মডেল প্রস্তুত হচ্ছে... (X%)" updates as
model loads → on ready, subtitle → "AI প্রস্তুত", mic activates, optional chime plays.
Never a hard swap between states; always a fade. The first 5 seconds are the user's
entire first impression — they must feel intentional, not "loading."

**13.6 Empty-chat suggestions.** Instead of "Type a message...", three Bangla pills:
`ORS কীভাবে বানাবো?` / `নিকটস্থ আশ্রয়কেন্দ্র` / `সাপে কামড়ালে কী করবো?`. Tappable.
Doubles as a soft tour of what the app does — the user learns the app's scope without
reading a manual.

**13.7 Returning-user detection.** First-launch shows the suggestion pills. Returning
user (any prior conversation in `shared_preferences`) sees their last conversation
restored. Signals "this app remembers me" = premium. The suggestions remain accessible
via a small "নতুন প্রশ্ন" (new question) chip at the bottom of the restored chat.

### C. Component polish (the second-look craft)

**13.8 Per-screen "moment."** Each screen has exactly one element that is more crafted
than the rest:
- Chat → the mic button (soft emboss, sand-colored bottom edge, ambient glow).
- Quick cards → the ORS card (32dp leading glyph vs 28dp for others).
- Hub → Tile 1 (1dp elevation that catches light differently).
- Shelter map → the user-location dot (1.4s pulse, calmTeal ring).
- Emergency sheet → the slide-to-confirm knob (deliberate drag).
- About → the 200dp branded header.
- Splash → the breathing "স".

**13.9 Custom hand-drawn icon set.** 10 icons, drawn to match the brand stroke weight,
exported as SVG → `flutter_svg`. Replaces Material defaults (`Icons.call`,
`Icons.shield`, etc.) on all user-facing surfaces. See §15 for the full set definition.
Material icons used only where no custom equivalent exists and never visible to the user
as "default Material."

**13.10 Tactile input border.** Chat text input is a 1dp hairline border at rest
(`calmTeal` at 30% opacity). On focus → 2dp border + `sand`-color fill. Subtle focus
state that carries information without being noisy. When the text field has content, the
border shifts to full `calmTeal`.

**13.11 Numbered Bangla steps.** Quick cards use `১. পানি ফুটিয়ে ঠাণ্ডা করুন। ২. এক চা
চামচ চিনি যোগ করুন।` Bangla numerals throughout, danda (।) as terminator. More
readable than bullets for sequential instructions; more premium-feeling than
icons-on-icons. Cards with non-sequential content (do/don't lists) use ✓ / ✗ marks in
`calmTeal` / `alertRed` — but these are the exception, not the default.

**13.12 TTS voice quality lock.** Phase 5 QA picks the most intelligible `bn-BD` voice
on the demo device, locks it in code via `flutter_tts` setVoice, documents the voice name
in §15. Default speech rate 0.9x for stressed-voice clarity. If no `bn-BD` voice is
available, fall back to `bn-IN` and log the substitution. Never silently use a non-Bangla
voice.

### D. Calm error & status

**13.13 Errors as moments, not messages.** Never "Permission denied" or "Error: null" or
"Something went wrong." Always Bangla, always actionable, always with a secondary
"পরিবর্তে..." (alternatively) path. Layout: 64dp custom glyph in `calmTeal` (not red), one
Bangla sentence explaining the state, primary action button, secondary "পরিবর্তে..."
link. No red full-screen errors. No skull/alert icons. No blame on the user.

Examples:
- No mic: "মাইক্রোফোন ব্যবহারের অনুমতি প্রয়োজন" → primary "অনুমতি দিন" → secondary
  "পরিবর্তে টাইপ করুন".
- No GPS: "অবস্থান পরিষেবা বন্ধ" → primary "চালু করুন" → secondary "পরিবর্তে সমগ্র
  এলাকা দেখুন".
- Model failed: "AI এই মুহূর্তে প্রস্তুত নয়" → primary "আবার চেষ্টা করুন" → secondary
  "পরিবর্তে জরুরি কার্ড দেখুন".

**13.14 Persistent AppBar micro-status.** A single line under the AppBar title (12sp,
70% opacity text — NOT a colored dot). Always present, always informative. Reads one of:
- "অফলাইন" (offline, both mic and model unavailable) — paired with breathing dot.
- "AI প্রস্তুত" (model loaded, ready).
- "AI প্রস্তুত হচ্ছে (৪৫%)" (model loading).
- "জিপিএস নেই" (location denied) — paired with amber underline.
- "মাইক্রোফোন নেই" (mic denied) — paired with stripe shimmer on mic button.

Color-coded only via text content (the word itself), never via background tint. The
status line is the user's always-visible answer to "what is the app doing right now."

---

## 14. User-Friendly Guarantees (6 items)

These are promises to the user, enforced in design and code review.

**14.1 Plain-language copy lock.** Every visible string is plain Bangla. "Hydration" →
"পানি ও লবণ"; "Symptom" → "লক্ষণ"; "Dehydration" → "পানিশূন্যতা"; "Evacuation" →
"নিরাপদ স্থানে যান". Universal acronyms (ORS, SMS, GPS, SOS) stay. Enforced in PR
review: if a reviewer sees an English word in user UI that isn't a whitelisted acronym,
the PR blocks.

**14.2 Always have a "পরিবর্তে..." path.** Every primary action has a secondary one.
Never a dead-end. Examples: dial 999 → "পরিবর্তে SOS পাঠান"; voice input → "পরিবর্তে
টাইপ করুন"; model answer → "পরিবর্তে জরুরি কার্ড দেখুন"; GPS shelter → "পরিবর্তে সমগ্র
এলাকা দেখুন". The user always has a way forward, even when something fails.

**14.3 Long-press AppBar title → help sheet.** 2-second long-press on the AppBar title
on any screen opens a one-page help sheet (bottom sheet, 20dp top corners). Contents:
what is this app, who built it, how to use voice, what happens offline, the data sources,
how to enable auto-read. Single screen, plain Bangla, scrollable. Always reachable, no
menu, no settings. Dismiss with tap-outside or system back.

**14.4 Density lock per screen.** (See §12 — encoded as a system lock.) Chat 24dp (airy),
quick cards 12dp (compact), hub 16dp (spacious), about 24dp (airy). One rhythm per screen
type. Intentional spacing, not arbitrary.

**14.5 Auto-read toggle.** Every answer has a "পড়ুন" button (existing). Long-press the
chat title (2s) toggles "auto-read on" mode — every assistant answer is spoken aloud
automatically, no button tap needed. For low-literacy / visually impaired users. Persisted
in `shared_preferences` key `auto_read_enabled` (default false). Visual indicator: a
small speaker glyph appears in the AppBar when auto-read is on.

**14.6 Every screen maps to a guarantee.** Quick-reference table:

| Screen | Primary guarantee | Secondary guarantee |
|---|---|---|
| Chat | Voice input works offline | Type fallback, auto-read toggle |
| Quick cards | Render without model | Seed phrase drops to chat |
| Shelter map | GPS nearest shelter | Bangladesh default if no GPS |
| Emergency sheet | Slide-to-confirm dial | SOS SMS fallback |
| Hub | One-tap to any feature | About/sources one tap away |
| About | Sources are attributable | Disclaimer always visible |
| Splash | App is alive, not loading | Fade, never hard swap |

---

## 15. Implementation Handoff

This section is the single source of truth for Maruf, Sehab, and Ahnaf when building.
If a value here conflicts with anything above, **this section wins** for implementation
purposes (and the above section should be updated to match).

### 15.1 TTS voice lock

| Parameter | Value |
|---|---|
| Language | `bn-BD` (fallback `bn-IN`) |
| Voice name | TBD in Phase 5 (locked after device QA) |
| Speech rate | `0.9` (0.0–1.0 scale, slower than default for clarity) |
| Pitch | `1.0` (default) |
| Volume | `1.0` (max — crisis context) |

```dart
// Phase 5: lock the voice name after testing on the demo device.
// Document the chosen voice name here:
//   voiceName: "<filled in Phase 5>"
```

### 15.2 Haptic event names

```dart
// lib/core/services/haptic_service.dart
enum HapticEvent {
  lightTap,      // mic press — lightImpact
  mediumTap,     // card open, selection — selectionClick
  success,       // answer rendered — mediumImpact
  warn,          // low-confidence answer — heavyImpact (single)
  strong,        // emergency confirmed — heavyImpact + vibrate
}
```

### 15.3 Sound file paths

```
assets/sound/
  chime.wav       # 1.5s app-open chime (Phase 5: Ahnaf sources/synthesizes)
  knock.wav       # 300ms answer-ready water-drop (Phase 5: Ahnaf sources/synthesizes)
```

Both registered in `pubspec.yaml` under `assets:`. Both gated by `shared_preferences`
keys `sound_chime_enabled` / `sound_knock_enabled` (default true), suppressed when system
ringer is silent.

### 15.4 Custom icon set (10 icons)

Drawn to match Hind Siliguri's stroke weight (medium). Exported as SVG → rendered via
`flutter_svg`. Stored in `assets/icons/`. Maruf draws these in Phase 1.2 or Phase 3
(alongside quick cards). Each icon is a single-color glyph (white on teal, or teal on
light surface) — no multi-color icons, no gradients.

| Icon name | Semantic meaning | Used on |
|---|---|---|
| `mic.svg` | microphone (rounded, single capsule) | chat input mic button |
| `send.svg` | paper plane / arrow (single stroke) | chat send button |
| `cards.svg` | stacked rectangles (3 offset) | AppBar cards icon |
| `phone.svg` | handset (simplified, not skeuomorphic) | AppBar emergency icon |
| `shield.svg` | shield with check | shelter markers, hub tile 2 |
| `water_drop.svg` | single drop | ORS card, hydration |
| `snake.svg` | stylized S-curve snake | snakebite card |
| `cross.svg` | plus (medical, not red-cross-trademark) | bleeding control, medical |
| `verified.svg` | circle with check | about page sources |
| `warning.svg` | triangle with exclamation | low-confidence chip, no-GPS |

```dart
// Usage pattern:
SvgPicture.asset('assets/icons/mic.svg',
  colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
  width: 24, height: 24,
)
```

### 15.5 Splash and app icon assets

```
assets/brand/
  icon_fg.svg          # white "স" glyph on transparent (adaptive icon foreground)
  icon_bg.svg          # calmTeal solid (adaptive icon background)
  splash_mark.svg      # white "স" at 96dp for splash
  splash_brand.svg     # "শঙ্গ্যোগ" in Display 28sp Hind Siliguri Semibold

android/app/src/main/res/
  mipmap-mdpi/ic_launcher.png      # 48x48
  mipmap-hdpi/ic_launcher.png      # 72x72
  mipmap-xhdpi/ic_launcher.png     # 96x96
  mipmap-xxhdpi/ic_launcher.png    # 144x144
  mipmap-xxxhdpi/ic_launcher.png   # 192x192
  mipmap-anydpi-v26/ic_launcher.xml  # adaptive icon (fg + bg)
```

PNG variants generated from `icon_fg.svg` + `icon_bg.svg` via Android Studio's Image
Asset tool or `flutter_launcher_icons` package (added in Phase 1.1 scaffolding).

### 15.6 Font registration (pubspec.yaml snippet)

```yaml
flutter:
  fonts:
    - family: HindSiliguri
      fonts:
        - asset: assets/fonts/HindSiliguri-Light.ttf
          weight: 300
        - asset: assets/fonts/HindSiliguri-Regular.ttf
          weight: 400
        - asset: assets/fonts/HindSiliguri-Medium.ttf
          weight: 500
        - asset: assets/fonts/HindSiliguri-SemiBold.ttf
          weight: 600
    # Per-screen fallback (see §12 Bangla conjunct rule):
    - family: NotoSerifBengali
      fonts:
        - asset: assets/fonts/NotoSerifBengali-Regular.ttf
          weight: 400
        - asset: assets/fonts/NotoSerifBengali-SemiBold.ttf
          weight: 600
```

```dart
// lib/core/theme.dart
static const String fontFamily = 'HindSiliguri';
static const String fontFamilyFallback = 'NotoSerifBengali';

static ThemeData lightTheme = ThemeData(
  fontFamily: fontFamily,
  // ... color tokens from §5.1
);

static ThemeData darkTheme = ThemeData(
  fontFamily: fontFamily,
  brightness: Brightness.dark,
  // ... dark color tokens from §5.1
);
```

### 15.7 Color token reference (for code)

```dart
// lib/core/theme.dart
abstract class ShongjogColors {
  // Light mode
  static const paperWhite = Color(0xFFFAF7F0);
  static const sand = Color(0xFFF4ECD8);
  static const inkBlack = Color(0xFF1A1A1A);
  static const calmTeal = Color(0xFF0E5E6F);
  static const softTeal = Color(0xFFE8F0F2);
  static const alertRed = Color(0xFFB23A48);

  // Dark mode
  static const darkBody = Color(0xFF0A1922);
  static const elevated = Color(0xFF112733);
  static const warmOffWhite = Color(0xFFF0EAE0);
  static const calmTealDark = Color(0xFF4FB3C8);  // calmTeal+
  static const softTealDark = Color(0xFF1A3540);
  static const alertRedDark = Color(0xFFE57180);  // alertRed+
  static const mutedText = Color(0xFFA8B5BC);
}
```

---

## Document maintenance

This doc is the single source of truth for UI. When a decision changes:
1. Update the relevant section above.
2. If the change affects implementation, update §15 (implementation handoff) — §15 wins
   for code purposes.
3. Note the change in `docs/team.md` §9 (decision log).
4. Do not let code drift from this doc. If code differs, either fix the code or update
   the doc — never both in limbo.
