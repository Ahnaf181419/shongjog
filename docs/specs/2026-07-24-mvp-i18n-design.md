# MVP i18n Design

## Goal
Add Bangla/English language toggle to Shongjog. User can switch between Bangla (default) and English from Settings or onboarding welcome page.

## Scope: ~212 strings across14 files
- `lib/app/main_shell.dart` — 4 nav labels
- `lib/app/app.dart` — 3 strings (splash, unknown route)
- `lib/features/onboarding/onboarding_screen.dart` —17 strings
- `lib/features/settings/settings_screen.dart` —52 strings
- `lib/features/home/home_screen.dart` —32 strings
- `lib/features/about/about_screen.dart` —12 strings
- `lib/features/contacts/emergency_contacts_screen.dart` —13 strings
- `lib/features/notifications/notifications_screen.dart` —5 strings
- `lib/features/emergency/directory_screen.dart` —12 strings
- `lib/features/safe_beacon/safe_beacon_screen.dart` —12 strings
- `lib/features/chat/chat_screen.dart` —20 strings
- `lib/features/mesh_comm/mesh_radar_screen.dart` —16 strings
- `lib/features/weather/weather_card.dart` —13 strings
- `lib/features/mesh_comm/mesh_service.dart` —1 string

## Out of scope (stay Bangla-only)
- LLM prompt templates, SOS SMS templates, urgency classifier keywords
- District/geographic names, quick cards data

## Architecture
1. `LocaleController` — `ChangeNotifier` singleton persisted to SharedPreferences
2. `.arb` files via `gen_l10n` — `app_bn.arb` (Bangla, default), `app_en.arb` (English)
3. `MaterialApp` wired with `localizationsDelegates`, `supportedLocales`, `locale` from `localeController`
4. Settings toggle in "উপস্থিতি" section
5. Language picker on onboarding welcome page (2 buttons: বাংলা / English)
6. Live switch during onboarding — MaterialApp rebuild propagates locale change

## Back button fix
- `onboarding_screen.dart:63` — change `pushReplacementNamed` → `pushNamed` + add `widget.onComplete()`
