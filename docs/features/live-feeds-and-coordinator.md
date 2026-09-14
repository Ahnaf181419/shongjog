# Live Telemetry Feeds & Coordinator Portal

## 1. The 13 Live Telemetry Endpoints

When internet connectivity is available, Shongjog continuously polls and enriches its offline baseline with **13 real-time, key-less, public telemetry feeds**:

```
                                 [ Shongjog Telemetry Engine ]
                                               │
             ┌─────────────────────────────────┼─────────────────────────────────┐
             ▼                                 ▼                                 ▼
      [ Disaster Feeds ]               [ Seismic Feeds ]                 [ Open-Meteo APIs ]
   • GDACS RSS/JSON Alerts            • USGS GeoJSON Feed              • Hourly Weather Forecasts
   • NASA EONET Active Events                                          • Marine Storm Surge Model
                                                                       • Air Quality Index (AQI/PM2.5)
```

### Feed Specifications & Fail-Soft Guarantees

| Endpoint | Provider | Data Ingested | Fail-Soft Mechanism |
|---|---|---|---|
| **GDACS Alerts** | UN / EC GDACS | Tropical cyclones, major riverine floods, severe droughts. | Cached in local storage. Retains last-known alert if request times out. |
| **NASA EONET** | NASA Earth Science | Wildfires, major meteorological disturbances, severe storms. | Network errors swallowed silently; falls back to static risk models. |
| **USGS Earthquakes** | USGS Seismic | Real-time global seismic events (M2.5+ worldwide, M1.0+ regional). | Returns empty set on failure; displays offline seismicity advice. |
| **Open-Meteo Weather** | Open-Meteo | Hourly precipitation, wind speed, gust velocity, barometric pressure. | Falls back to cached local weather profile. |
| **Open-Meteo Marine** | Open-Meteo | Wave height, wave period, coastal storm surge anomaly. | Essential for coastal districts (Cox's Bazar, Bhola, Patuakhali). |
| **Open-Meteo AQI** | Open-Meteo | PM2.5, PM10, AQI, ozone, sulfur dioxide levels. | Provides smog and air toxicity advisories. |

> **Fail-Soft Invariant:**  
> All HTTP requests use strict connection timeouts (5 to 10 seconds). No network exception is allowed to bubble up to the widget tree. If all 13 feeds fail simultaneously (e.g., during cellular throttling), the UI seamlessly displays cached telemetry alongside the offline guidance cards.

---

## 2. Coordinator Dashboard & Admin Panel

The Admin & Coordinator Module ([`lib/features/admin/`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/admin)) provides emergency operations centers (EOC) and Red Crescent field coordinators with situational awareness.

### Key Capabilities
- **Live Safe / Danger Status Counter**: Aggregate real-time counter of community members who have activated their status beacon.
- **Distress Ping Heatmap**: Visual pin-mapping of incoming citizen distress reports, showing name, contact number, battery level, timestamp, and accurate GPS coordinates.
- **Official Broadcast Alerts**: Ability for authorized emergency managers to dispatch broadcast push alerts and SMS campaign advisories.
- **Campaign Approvals**: Field volunteer coordination and relief distribution requests.

---

## 3. Firestore Security Model (`firestore.rules`)

Citizen safety reports carry sensitive personal data (names, mobile numbers, precise live GPS coordinates). Shongjog enforces strict access control rules defined in [`firestore.rules`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/firestore.rules):

### Scope & Structure
The backend explicitly scopes rules across **4 collections**:
1. `safety_reports`: Citizen distress/safe reports.
2. `campaigns`: Disaster relief coordination campaigns.
3. `broadcasts`: Official emergency alerts dispatched to all devices.
4. `users/{uid}`: Per-user account documents tracking claimed roles (`admin` vs standard).

### Rule Excerpt & Logic
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isAdmin() {
      return isSignedIn() &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Ownership verification using ownerUid (stamped by withOwnerUid() in core)
    function ownsIncoming() {
      return isSignedIn() && request.resource.data.ownerUid == request.auth.uid;
    }

    function ownsExisting() {
      return isSignedIn() && resource.data.ownerUid == request.auth.uid;
    }

    // Safety Reports: Created/updated only by owner; read access restricted to admins
    match /safety_reports/{reportId} {
      allow create: if ownsIncoming();
      allow update: if ownsExisting() && ownsIncoming();
      allow read: if isAdmin() || ownsExisting();
      allow delete: if isAdmin() || ownsExisting();
    }

    // Broadcasts: Dispatched strictly by admins; readable by any signed-in user
    match /broadcasts/{broadcastId} {
      allow read: if isSignedIn();
      allow create, update, delete: if isAdmin();
    }

    // Campaigns: Created by signed-in users, but approved/managed by admins
    match /campaigns/{campaignId} {
      allow read: if isSignedIn();
      allow create: if ownsIncoming();
      allow update, delete: if isAdmin() || ownsExisting();
    }

    // User Documents: Users manage their own doc
    match /users/{userId} {
      allow read: if isSignedIn();
      allow write: if isSignedIn() && request.auth.uid == userId;
    }
  }
}
```

### Security Considerations & Known Limitations
- **Anonymous Auth Model**: Devices authenticate anonymously with Firebase Auth without requiring SMS OTP during a crisis.
- **Client-Asserted Admin Gate**: In the current hackathon milestone, the admin role is claimed by the device after entering a local PIN screen. For production deployments, role assignment must transition to server-side issuance (e.g. Cloud Function or Firebase Custom Claims) to prevent unauthorized broadcasts.
