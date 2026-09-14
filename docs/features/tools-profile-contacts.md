# Tools, User Profile & Emergency Contacts

## 1. Tools Tab Navigation Grid

The **Tools** tab ([`lib/features/tools/tools_screen.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/tools/tools_screen.dart)) provides direct, prominent access to the five primary AI-assisted disaster management tools:

```
+-------------------------------------------------------------+
|                         TOOLS TAB                           |
+------------------------------+------------------------------+
| [ Icons.assignment ]         | [ Icons.luggage ]            |
| Family Disaster Planner      | AI Emergency Kit Generator   |
| Route: /planner              | Route: /kit                  |
+------------------------------+------------------------------+
| [ Icons.shield ]             | [ Icons.camera_alt ]         |
| AI Risk Assessment           | AI Damage Scanner            |
| Route: /risk                 | Route: /damage_scanner       |
+------------------------------+------------------------------+
| [ Icons.summarize ]          |                              |
| Situation Summary            |                              |
| Route: /situation_summary    |                              |
+------------------------------+------------------------------+
```

Every tile navigates using `pushNamedSafe`, ensuring that tapping multiple cards rapidly during an emergency does not corrupt the navigation stack.

---

## 2. User Profile & Behavioral Intelligence

User profile state is managed across three specialized layers:

### A. Personal Identity Profile (`UserProfileData`)
- **File Location**: [`lib/features/profile/profile_screen.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/profile/profile_screen.dart)
- **Fields**: Name, phone number, photo path, blood group, and home district.
- **District Taxonomy**: Mapped against all 64 districts across the 8 administrative divisions of Bangladesh using [`assets/geo/districts.json`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/assets/geo/districts.json).
- **Emergency Injection**: The user's name, phone, and district are automatically injected into the SOS SMS message template and live safety reports.

### B. Household Family Profile (`FamilyProfile`)
- **File Location**: [`lib/features/planner/family_profile.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/planner/family_profile.dart)
- **Fields**: Total family headcount, infants count, elderly count, pregnant members, family pets, special medical needs (insulin, dialysis, oxygen), and dwelling structural construction.
- **Consumption**: Consumed by the Family Disaster Planner and Kit Generator to produce calibrated emergency supply and evacuation calculations.

### C. Behavioral Intelligence Engine (`UserProfile`)
- **File Location**: [`lib/features/intelligence/user_profile.dart`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/intelligence/user_profile.dart)
- **Role**: Lightweight in-memory behavioral tracker.
- **Mechanics**: Tracks search query frequencies and detected topics (`showsCycloneInterest`, `showsFloodInterest`, `showsMedicalInterest`).
- **Proactive Advisories**: Triggers proximity notifications and contextual home suggestions when a user's geographic area or recent query pattern matches an incoming GDACS/NASA hazard alert.

---

## 3. Emergency Contacts System

The Contacts feature ([`lib/features/contacts/`](file:///home/frostflux/Ahnaf_Shafin/Hackathon/shongjog/lib/features/contacts)) gives immediate access to national crisis lifelines and trusted personal contacts.

### Directory Merging
The `ContactsRepository` merges two sources of numbers:
1. **22 Bundled National Hotlines** (`assets/emergency/directory.json`):
   - National Emergency Service: `999`
   - National Disaster Helpline: `1090`
   - Fire Service & Civil Defence: `102`
   - Women & Child Abuse Prevention: `109`
   - Bangladesh Red Crescent Society (BDRCS) Headquarters
   - Cyclone Preparedness Programme (CPP) Coastal Control Rooms
2. **Custom User Contacts**:
   - Family members, local doctors, and neighbors added by the user.
   - Persisted locally as JSON within `SharedPreferences` (`custom_contacts`).

### Contact Categorization (`ContactCategory`)
Contacts are filtered across 7 semantic categories:
- `police`: Local police stations and metropolitan patrol desks.
- `fire`: Fire stations and search & rescue teams.
- `ambulance`: Hospital ambulance dispatch lines.
- `disaster`: CPP units, flood control centers, meteorological office.
- `redCrescent`: BDRCS disaster response teams.
- `health`: Government civil surgeon offices and upazila health complexes.
- `other`: Local community leaders and neighborhood rescue volunteers.
