# Firebase Backend Integration Plan — Shongjog

> **Goal:** Add a minimal Firebase backend so that admin ↔ user communication works
> across devices, push notifications deliver broadcasts/hazards, and static data
> (directory, shelters) can be updated without APK re-releases.
>
> **Timeline:** Hackathon demo scope (1–2 days)

## Guiding Principles

- **Offline-first preserved.** Every Firestore write is queued locally; reads fall
  back to local cache. The app works in airplane mode — Firebase syncs when online.
- **No PII in analytics.** Firebase Analytics with anonymous IDs only. Crashlytics
  for stability. No chat content, voice, GPS, or photos leave the device beyond the
  explicit Firestore fields below.
- **Minimal surface.** Only the 4 existing admin features (dashboard, users,
  campaigns, broadcasts) + safety reports get wired to Firestore. No new features
  beyond what's needed.

---

## Phase 1 — Firebase Project Setup (30 min)

### 1.1 Create Firebase project

- Go to [console.firebase.google.com](https://console.firebase.google.com), create
  project `shongjog`
- Enable: **Authentication** (Phone provider), **Cloud Firestore**, **Cloud
  Messaging**, **Remote Config**, **Crashlytics**

### 1.2 FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=shongjog
```

This generates `lib/firebase_options.dart` (gitignored) with per-platform config.

### 1.3 Add dependencies to `pubspec.yaml`

```yaml
# Firebase
firebase_core: ^3.12.0
firebase_auth: ^5.5.0
cloud_firestore: ^5.6.0
firebase_messaging: ^15.2.0
firebase_crashlytics: ^4.3.0
firebase_analytics: ^11.4.0
firebase_remote_config: ^5.3.0
```

### 1.4 Initialize in `main.dart`

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
// Anonymous analytics — no PII
await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
```

Insert between `WidgetsFlutterBinding.ensureInitialized()` and
`FlutterGemma.initialize(...)`.

**Files modified:** `pubspec.yaml`, `lib/main.dart`

---

## Phase 2 — Firestore Data Model & Security Rules (30 min)

### 2.1 Collections

```
firestore/
  users/{uid}
    name: string
    phone: string
    division: string           // 'dhaka' | 'chattogram' | etc.
    role: 'user' | 'admin'
    lastLat: number | null
    lastLon: number | null
    lastSeen: timestamp
    createdAt: timestamp

  campaigns/{campaignId}
    userId: string
    userName: string
    userPhone: string
    type: number               // CampaignType.index
    latitude: number
    longitude: number
    address: string
    landmark: string
    description: string
    timestamp: timestamp
    status: 'pending' | 'approved' | 'rejected'
    adminNotes: string | null
    reviewedAt: timestamp | null

  broadcasts/{broadcastId}
    text: string
    timestamp: timestamp
    sentBy: string             // admin uid

  safety_reports/{uid}
    userId: string
    userName: string
    userPhone: string
    status: 'safe' | 'danger'
    dangerType: string | null
    note: string
    lat: number | null
    lon: number | null
    timestamp: timestamp
    hopCount: number
```

### 2.2 Security rules (`firestore.rules`)

```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users: read your own, write your own profile
    match /users/{uid} {
      allow read: if request.auth != null;
      allow create: if request.auth.uid == uid;
      allow update: if request.auth.uid == uid
        || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    // Campaigns: anyone auth'd can create, only admin can update status
    match /campaigns/{id} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    // Broadcasts: only admin can create, anyone auth'd can read
    match /broadcasts/{id} {
      allow read: if request.auth != null;
      allow create: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    // Safety reports: write your own, read all
    match /safety_reports/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == uid;
    }
  }
}
```

### 2.3 Seed admin user

After first admin signs in with phone auth, manually set their `role` to `'admin'`
in Firestore (or use a Cloud Function later). For the hackathon, a one-time manual
step is fine.

**Files created:** `firestore.rules`, `firestore.indexes.json`

---

## Phase 3 — Auth Service (1 hour)

### 3.1 Create `lib/core/auth_service.dart`

```dart
class AuthService extends ChangeNotifier {
  User? get currentUser => FirebaseAuth.instance.currentUser;
  bool get isAdmin => ...; // read from Firestore users/{uid}.role
  bool get isSignedIn => currentUser != null;

  Future<void> signInWithPhone(
    String phoneNumber, {
    required void Function(PhoneAuthCredential) onCompleted,
    ...
  });

  Future<void> verifyPhoneNumber({required String phoneNumber, ...});
  Future<void> signOut();
  Future<void> _createUserDoc(User user); // write initial users/{uid}
}
```

### 3.2 Replace `AdminLoginScreen`

- User enters phone number → receives OTP → verifies → signs in
- On first sign-in, create `users/{uid}` doc with `role: 'user'`
- Admin detection: check `users/{uid}.role == 'admin'` from Firestore
- For the hackathon demo: manually set one user as admin in Firestore console

### 3.3 Update `_StartupGate` in `app.dart`

- After onboarding, check `AuthService.isSignedIn`
- If signed in → `MainShell`
- If not signed in → show sign-in screen (or allow offline skip)
- Admin panel routes: gate behind `AuthService.isAdmin`

**Files created:** `lib/core/auth_service.dart`
**Files modified:** `lib/features/admin/admin_login_screen.dart`, `lib/app/app.dart`, `lib/main.dart`

---

## Phase 4 — Wire Admin Panel to Firestore (2 hours)

### 4.1 Create `lib/core/firestore_service.dart`

Central Firestore wrapper:

```dart
class FirestoreService {
  // Campaigns
  Stream<List<CampaignRequest>> watchCampaigns();
  Future<void> submitCampaign(CampaignRequest req);
  Future<void> updateCampaignStatus(
    String id, CampaignStatus status, {String? notes});

  // Broadcasts
  Stream<List<AdminMessage>> watchBroadcasts();
  Future<void> sendBroadcast(String text);

  // Safety reports
  Stream<List<SafetyReport>> watchSafetyReports();
  Future<void> updateMySafetyStatus(SafetyReport report);

  // Users (admin only)
  Stream<List<UserProfile>> watchUsers();
}
```

### 4.2 Replace `CampaignRequestService` local JSON with Firestore

- `submitCampaign()` → `FirebaseFirestore.instance
    .collection('campaigns').doc(id).set(req.toJson())`
- `watchCampaigns()` → real-time stream via `.snapshots()`
- `updateRequestStatus()` → admin updates doc in Firestore
- **Keep local fallback:** if offline, queue write to local JSON; sync when online

### 4.3 Replace `AdminBroadcastService` local JSON with Firestore

- `addMessage()` → `FirebaseFirestore.instance
    .collection('broadcasts').doc(id).set({...})`
- `watchBroadcasts()` → real-time stream
- **Push notification:** on broadcast create, trigger FCM to all users
  (via Cloud Function or client-side)

### 4.4 Extend `SafetyStatusService` to sync with Firestore

- `ingest()` → also write to `safety_reports/{uid}` in Firestore
- `watchSafetyReports()` → real-time stream for admin dashboard
- **Mesh reports still work offline** — Firestore is a second channel for when online

### 4.5 Update admin UI pages (`admin_pages.dart`)

- `AdminDashboardPage` → listen to Firestore streams for live stats
- `AdminUsersPage` → listen to `users` collection (all registered users, not just
  mesh peers)
- `AdminCampaignsPage` → listen to Firestore campaigns stream
- `AdminBroadcastPage` → write to Firestore instead of local file
- `AdminDangerListPage` → listen to Firestore safety_reports stream

**Files created:** `lib/core/firestore_service.dart`
**Files modified:** `lib/features/admin/campaign_request.dart`,
`lib/core/admin_broadcast_service.dart`,
`lib/features/safe_beacon/safety_status_service.dart`,
`lib/features/admin/admin_pages.dart`,
`lib/features/admin/admin_panel_screen.dart`

---

## Phase 5 — Push Notifications (1 hour)

### 5.1 Create `lib/core/notification_service.dart`

```dart
class NotificationService {
  Future<void> initialize(); // request permission, get FCM token
  Future<void> subscribeToTopic(String topic); // 'hazards', 'broadcasts'
  void onMessage(RemoteMessage message); // show in-app notification
}
```

### 5.2 Wire to admin broadcasts

- When admin sends a broadcast → write to Firestore → Cloud Function triggers
  FCM to topic `broadcasts`
- All users subscribed to `broadcasts` topic receive push
- On tap: navigate to notifications screen

### 5.3 Wire to hazard alerts

- Subscribe all users to `hazards` topic
- Cloud Function (or admin trigger) sends FCM when new EONET/GDACS/USGS event
  is detected
- For the hackathon: admin manually triggers a hazard broadcast from the admin panel

### 5.4 Notifications screen

- List of received FCM messages + admin broadcasts
- Read/unread state persisted in SharedPreferences

### 5.5 FCM token for targeted messaging

- Store FCM token in `users/{uid}` document
- Admin can send to specific users (future use)

**Files created:** `lib/core/notification_service.dart`
**Files modified:** `lib/main.dart` (init),
`lib/features/admin/admin_pages.dart` (broadcast triggers FCM)

---

## Phase 6 — Remote Config for Data Freshness (1 hour)

### 6.1 Emergency directory updates

- Store `directory.json` content in Remote Config (max 1MB; 22 entries ≈ 5KB,
  well within limit)
- App reads Remote Config on startup when online, falls back to bundled asset
- Admin updates directory entries via Firebase Console → users get update on
  next launch

### 6.2 Shelter list updates

- Store shelter GeoJSON in Remote Config (or Firestore for larger datasets)
- Same fallback pattern: Remote Config → bundled asset

### 6.3 Feature flags

- `maintenance_mode`: boolean to show a maintenance banner
- `model_download_enabled`: boolean to pause model downloads
- `cloud_ai_enabled`: boolean to toggle cloud fallback

### 6.4 Implementation

```dart
class RemoteConfigService {
  Future<void> initialize(); // fetchAndActivate()
  String get directoryJson => remoteConfig.getString('emergency_directory');
  String get shelterGeoJson => remoteConfig.getString('shelter_list');
  bool get maintenanceMode => remoteConfig.getBool('maintenance_mode');
}
```

### 6.5 Update loaders

- `DirectoryLoader.loadAll()` → try Remote Config first, fall back to asset
- `ShelterRepository.loadAll()` → try Remote Config first, fall back to asset

**Files created:** `lib/core/remote_config_service.dart`
**Files modified:** `lib/features/emergency/directory_loader.dart`,
`lib/features/shelter/shelter_repository.dart`

---

## Phase 7 — Anonymous Analytics + Crashlytics (30 min)

### 7.1 Crashlytics

- Already initialized in Phase 1
- Add in `main.dart`:
  ```dart
  FlutterError.onError =
      FirebaseCrashlytics.instance.recordFlutterFatalErrors;
  ```
- Add `FirebaseCrashlytics.instance.recordError(e, st)` in catch blocks for
  model init, mesh start, etc.
- **No chat content, voice, GPS, or photos** — only error messages and stack traces

### 7.2 Analytics (anonymous)

- Log custom events (no PII):
  - `chat_query` with `{tier: 'cloud'|'device'|'corpus', offline: true|false}`
  - `model_download_started`, `model_download_completed`
  - `sos_sent`, `campaign_submitted`
  - `mesh_peer_connected`
- **Never log:** query text, voice audio, GPS coordinates, photos, user names,
  phone numbers

### 7.3 Implementation

```dart
// In chat_repository.dart
FirebaseAnalytics.instance.logEvent(
  name: 'chat_query',
  parameters: {'tier': path.name, 'offline': !isOnline},
);

// In model_manager.dart
FirebaseAnalytics.instance.logEvent(
  name: 'model_download_completed',
  parameters: {
    'variant': variant.name,
    'size_mb': size ~/ 1024 ~/ 1024,
  },
);
```

**Files modified:** `lib/main.dart`, `lib/features/chat/chat_repository.dart`,
`lib/core/model_manager.dart`

---

## Phase 8 — Testing & Demo Prep (1 hour)

### 8.1 Unit tests

- `FirestoreService` — mock FirebaseFirestore, test CRUD operations
- `AuthService` — mock FirebaseAuth, test sign-in flow
- `NotificationService` — mock FCM, test initialization

### 8.2 Widget tests

- `AdminLoginScreen` — test phone auth flow
- `AdminPanelScreen` — test Firestore stream rendering
- `AdminBroadcastPage` — test send broadcast

### 8.3 Integration test

- Full flow: sign in → submit campaign → admin approves → broadcast sent →
  user receives push
- Run on real device with Firebase emulator or live project

### 8.4 Demo script

1. Admin signs in with phone (shows real auth)
2. Dashboard shows live user count from Firestore
3. User submits campaign request → appears in admin panel in real-time
4. Admin approves → user sees status update
5. Admin sends broadcast → all users receive push notification
6. Safety report: user presses "Danger" → admin sees it in danger list with GPS

---

## File Summary

| Action | File | Purpose |
|--------|------|---------|
| **Create** | `lib/core/auth_service.dart` | Firebase Phone Auth wrapper |
| **Create** | `lib/core/firestore_service.dart` | Central Firestore CRUD |
| **Create** | `lib/core/notification_service.dart` | FCM init + topic subscription |
| **Create** | `lib/core/remote_config_service.dart` | Remote Config for data freshness |
| **Create** | `lib/firebase_options.dart` | FlutterFire auto-generated |
| **Create** | `firestore.rules` | Security rules |
| **Modify** | `pubspec.yaml` | Add 7 Firebase packages |
| **Modify** | `lib/main.dart` | Firebase init + analytics + crashlytics |
| **Modify** | `lib/app/app.dart` | Auth gate in `_StartupGate` |
| **Modify** | `lib/features/admin/admin_login_screen.dart` | Phone auth instead of hardcoded |
| **Modify** | `lib/features/admin/admin_pages.dart` | Firestore streams instead of local reads |
| **Modify** | `lib/features/admin/admin_panel_screen.dart` | Firestore-backed stats |
| **Modify** | `lib/features/admin/campaign_request.dart` | Firestore writes + local fallback |
| **Modify** | `lib/core/admin_broadcast_service.dart` | Firestore writes + FCM trigger |
| **Modify** | `lib/features/safe_beacon/safety_status_service.dart` | Firestore sync |
| **Modify** | `lib/features/emergency/directory_loader.dart` | Remote Config fallback |
| **Modify** | `lib/features/shelter/shelter_repository.dart` | Remote Config fallback |
| **Modify** | `lib/features/chat/chat_repository.dart` | Analytics logging |
| **Modify** | `lib/core/model_manager.dart` | Analytics + crashlytics logging |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Firebase project setup delays | Use `flutterfire configure` — 5 min if CLI is installed |
| Phone auth requires real phone number | For hackathon demo, use Firebase test numbers or emulator |
| Firestore offline persistence | Enabled by default on Android/iOS — no extra config |
| FCM requires Google Play Services | Works on all Android devices with GMS; degraded on Huawei |
| Security rules complexity | Start permissive for demo, tighten post-hackathon |
| `google-services.json` / `GoogleService-Info.plist` in git | Add to `.gitignore`; use CI env vars or manual setup |
