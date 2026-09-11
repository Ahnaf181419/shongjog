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

Citizen safety reports carry sensitive personal data (names, mobile numbers, precise live GPS coordinates). To prevent scraping or unauthorized tampering, Shongjog enforces strict access control rules defined in [`firestore.rules`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/firestore.rules):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Safety Status Reports: User can only read and write their own record
    match /safety_reports/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Coordinator Access: Only verified coordinators can read aggregate reports
    match /coordinator_metrics/{metricId} {
      allow read: if request.auth != null && request.auth.token.role == 'coordinator';
      allow write: if false; // System / Cloud Function generated only
    }
    
    // Cloud AI Configuration: Readable by all authenticated users, writable by none
    match /config/cloud_ai {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}
```

> **Crucial Deployment Note:**  
> Firestore rules in the repository serve as the source of truth, but they take effect **only after being deployed or pasted into the Firebase Console**. Committing the file locally does not automatically update cloud enforcement.
