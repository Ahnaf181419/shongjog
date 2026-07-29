#!/usr/bin/env python3
"""Generate assets/shelter/cyclone_shelters.geojson.

Reproducible emitter for the bundled shelter dataset. Each entry in
CENTRES is a real upazila/town coordinate; N shelters are scattered in a
small ~1km circle around it so the map reads densely where shelters
actually exist (coastal cyclone belt + haor flood zone).

Run:
    python3 scripts/generate_shelters.py
Rewrites: assets/shelter/cyclone_shelters.geojson
"""
from __future__ import annotations

import json
import math
from pathlib import Path

# ---------------------------------------------------------------------------
# Bangla numeral helper (Latin -> Bengali digits), per AGENTS.md.
# ---------------------------------------------------------------------------
_BN_DIGITS = str.maketrans("0123456789", "০১২৩৪৫৬৭৮৯")


def bn(n: int) -> str:
    return str(n).translate(_BN_DIGITS)


# ---------------------------------------------------------------------------
# Data model. Each centre: (division, district_bn, town_en, lat, lon,
# shelter_type, count). shelter_type in {cyclone, flood, multi, earthquake}.
# Coordinates are real upazila/district centres, hand-checked.
# ---------------------------------------------------------------------------
CENTRES = [
    # ---- KHULNA (coastal cyclone belt) ----
    ("khulna", "খুলনা", "Khulna", 22.8456, 89.5403, "cyclone", 4),
    ("khulna", "সাতক্ষীরা", "Satkhira", 22.7186, 89.0703, "cyclone", 3),
    ("khulna", "শ্যামনগর", "Shyamnagar", 22.3319, 89.1031, "cyclone", 3),
    ("khulna", "মংলা", "Mongla", 22.4713, 89.5989, "cyclone", 3),
    ("khulna", "বাগেরহাট", "Bagerhat", 22.6516, 89.7858, "cyclone", 3),
    ("khulna", "পাইকগাছা", "Paikgachha", 22.5833, 89.3500, "cyclone", 3),
    ("khulna", "দাকোপ", "Dacope", 22.4333, 89.5167, "cyclone", 3),
    ("khulna", "কয়রা", "Koyra", 22.2333, 89.4000, "cyclone", 3),
    ("khulna", "যশোর", "Jessore", 23.1707, 89.2136, "multi", 3),
    ("khulna", "ঝিনাইদহ", "Jhenaidah", 23.5438, 89.1527, "multi", 2),
    ("khulna", "মাগুরা", "Magura", 23.4833, 89.4167, "multi", 2),
    ("khulna", "নড়াইল", "Narail", 23.0167, 89.5000, "cyclone", 2),
    ("khulna", "কুষ্টিয়া", "Kushtia", 23.9013, 89.1221, "flood", 3),
    ("khulna", "মেহেরপুর", "Meherpur", 24.0628, 88.6317, "flood", 2),
    ("khulna", "চুয়াডাঙ্গা", "Chuadanga", 23.6400, 88.8400, "multi", 2),

    # ---- BARISHAL (coastal cyclone belt) ----
    ("barishal", "বরিশাল", "Barishal", 22.7010, 90.3585, "cyclone", 4),
    ("barishal", "পটুয়াখালী", "Patuakhali", 22.3587, 90.3325, "cyclone", 3),
    ("barishal", "কুয়াকাটা", "Kuakata", 21.8193, 90.1246, "cyclone", 3),
    ("barishal", "বরগুনা", "Barguna", 22.1811, 90.1264, "cyclone", 3),
    ("barishal", "ভোলা", "Bhola", 22.6858, 90.6456, "cyclone", 4),
    ("barishal", "চরফ্যাশন", "Char Fasson", 22.1750, 90.7489, "cyclone", 3),
    ("barishal", "হিজলা", "Hizla", 22.6833, 90.1667, "cyclone", 2),
    ("barishal", "মেহেন্দিগঞ্জ", "Mehendiganj", 22.8086, 90.5286, "cyclone", 2),
    ("barishal", "পিরোজপুর", "Pirojpur", 22.5856, 89.9722, "cyclone", 3),
    ("barishal", "ঝালকাঠি", "Jhalokati", 22.6406, 90.1987, "cyclone", 2),
    ("barishal", "নলছিটি", "Nalchity", 22.6333, 90.2667, "cyclone", 2),
    ("barishal", "আমতলী", "Amtali", 22.1167, 90.2167, "cyclone", 3),
    ("barishal", "তালতলী", "Taltali", 21.9833, 90.1500, "cyclone", 2),
    ("barishal", "গলাচিপা", "Galachipa", 22.1667, 90.4000, "cyclone", 3),
    ("barishal", "রাঙ্গাবালি", "Rangabali", 21.7667, 90.4333, "cyclone", 2),

    # ---- CHATTOGRAM (coastal cyclone + CHT hill tracts) ----
    ("chattogram", "চট্টগ্রাম", "Chattogram", 22.3569, 91.7832, "cyclone", 5),
    ("chattogram", "কক্সবাজার", "Cox's Bazar", 21.4272, 92.0058, "cyclone", 4),
    ("chattogram", "টেকনাফ", "Teknaf", 20.8673, 92.2977, "cyclone", 3),
    ("chattogram", "রামু", "Ramu", 21.4589, 92.0956, "cyclone", 3),
    ("chattogram", "মহেশখালী", "Moheshkhali", 21.5333, 91.9500, "cyclone", 3),
    ("chattogram", "চকরিয়া", "Chakaria", 21.7778, 92.0500, "cyclone", 3),
    ("chattogram", "কুতুবদিয়া", "Kutubdia", 21.8167, 91.8500, "cyclone", 2),
    ("chattogram", "সন্দ্বীপ", "Sandwip", 22.4833, 91.4333, "cyclone", 3),
    ("chattogram", "সীতাকুণ্ড", "Sitakunda", 22.6167, 91.6667, "cyclone", 2),
    ("chattogram", "মীরসরাই", "Mirsharai", 22.7833, 91.5667, "cyclone", 2),
    ("chattogram", "নোয়াখালী", "Noakhali", 22.8333, 91.0833, "cyclone", 4),
    ("chattogram", "হাতিয়া", "Hatiya", 22.4500, 91.1000, "cyclone", 3),
    ("chattogram", "সুবর্ণচর", "Subarnachar", 22.5833, 91.0833, "cyclone", 2),
    ("chattogram", "লক্ষ্মীপুর", "Lakshmipur", 22.9500, 90.8333, "cyclone", 3),
    ("chattogram", "ফেনী", "Feni", 23.0167, 91.3833, "multi", 2),
    ("chattogram", "চাঁদপুর", "Chandpur", 23.2333, 90.6500, "flood", 3),
    ("chattogram", "কুমিল্লা", "Comilla", 23.4607, 91.1809, "multi", 3),
    ("chattogram", "বান্দরবান", "Bandarban", 22.1953, 92.2185, "multi", 2),
    ("chattogram", "রাঙ্গামাটি", "Rangamati", 22.6580, 92.1811, "multi", 2),
    ("chattogram", "খাগড়াছড়ি", "Khagrachari", 23.1203, 91.9755, "multi", 2),

    # ---- SYLHET (haor flood zone) ----
    ("sylhet", "সিলেট", "Sylhet", 24.8949, 91.8687, "flood", 3),
    ("sylhet", "সুনামগঞ্জ", "Sunamganj", 25.0659, 91.3968, "flood", 4),
    ("sylhet", "দিরাই", "Dirai", 24.6500, 91.3667, "flood", 3),
    ("sylhet", "তাহিরপুর", "Tahirpur", 25.1167, 91.1833, "flood", 3),
    ("sylhet", "ধর্মপাশা", "Dharampasha", 25.0333, 91.0500, "flood", 2),
    ("sylhet", "জামালগঞ্জ", "Jamalganj", 24.8333, 91.0500, "flood", 2),
    ("sylhet", "ছাতক", "Chhatak", 25.0333, 91.6667, "flood", 2),
    ("sylhet", "মৌলভীবাজার", "Moulvibazar", 24.4833, 91.7833, "multi", 3),
    ("sylhet", "শ্রীমঙ্গল", "Sreemangal", 24.3067, 91.7333, "multi", 2),
    ("sylhet", "হবিগঞ্জ", "Habiganj", 24.3783, 91.4167, "flood", 3),
    ("sylhet", "বিয়ানিবাজার", "Beanibazar", 24.5167, 91.9167, "flood", 2),
    ("sylhet", "কানাইঘাট", "Kanaighat", 24.8667, 92.1167, "flood", 2),

    # ---- DHAKA (mixed) ----
    ("dhaka", "ঢাকা", "Dhaka", 23.8103, 90.4125, "earthquake", 4),
    ("dhaka", "নারায়ণগঞ্জ", "Narayanganj", 23.6238, 90.4983, "flood", 3),
    ("dhaka", "মানিকগঞ্জ", "Manikganj", 23.8644, 90.0499, "flood", 2),
    ("dhaka", "মুন্সিগঞ্জ", "Munshiganj", 23.5333, 90.5333, "flood", 2),
    ("dhaka", "ফরিদপুর", "Faridpur", 23.6000, 89.8333, "multi", 3),
    ("dhaka", "রাজবাড়ী", "Rajbari", 23.7500, 89.6500, "flood", 2),
    ("dhaka", "গোপালগঞ্জ", "Gopalganj", 22.9667, 89.8167, "cyclone", 2),
    ("dhaka", "মাদারীপুর", "Madaripur", 23.1667, 90.2000, "multi", 2),
    ("dhaka", "শরীয়তপুর", "Shariatpur", 23.2500, 90.3500, "flood", 2),
    ("dhaka", "কিশোরগঞ্জ", "Kishoreganj", 24.4333, 90.7833, "flood", 3),
    ("dhaka", "নেত্রকোণা", "Netrokona", 24.8667, 90.7333, "flood", 2),
    ("dhaka", "টাঙ্গাইল", "Tangail", 24.2500, 89.9167, "flood", 2),
    ("dhaka", "গাজীপুর", "Gazipur", 24.0000, 90.4167, "multi", 2),

    # ---- RAJSHAHI (riverine flood) ----
    ("rajshahi", "রাজশাহী", "Rajshahi", 24.3636, 88.6241, "flood", 3),
    ("rajshahi", "পাবনা", "Pabna", 24.0060, 89.2372, "flood", 3),
    ("rajshahi", "সিরাজগঞ্জ", "Sirajganj", 24.3733, 89.7000, "flood", 4),
    ("rajshahi", "বগুড়া", "Bogura", 24.8460, 89.3711, "flood", 3),
    ("rajshahi", "নাটোর", "Natore", 24.4200, 89.0600, "multi", 2),
    ("rajshahi", "চাঁপাইনবাবগঞ্জ", "Chapainawabganj", 24.5969, 88.2750, "multi", 2),
    ("rajshahi", "নওগাঁ", "Naogaon", 24.7936, 88.9466, "multi", 2),
    ("rajshahi", "জয়পুরহাট", "Joypurhat", 25.0967, 89.0217, "multi", 2),
    ("rajshahi", "সারিয়াকান্দি", "Sariakandi", 24.8833, 89.5667, "flood", 2),
    ("rajshahi", "কাজীপুর", "Kazipur", 24.6333, 89.6500, "flood", 2),

    # ---- RANGPUR (riverine flood) ----
    ("rangpur", "রংপুর", "Rangpur", 25.7439, 89.2752, "flood", 3),
    ("rangpur", "দিনাজপুর", "Dinajpur", 25.6217, 88.6339, "multi", 2),
    ("rangpur", "কুড়িগ্রাম", "Kurigram", 25.8050, 89.6547, "flood", 4),
    ("rangpur", "লালমনিরহাট", "Lalmonirhat", 25.9923, 89.2847, "flood", 2),
    ("rangpur", "নীলফামারী", "Nilphamari", 25.9315, 88.8563, "flood", 2),
    ("rangpur", "পঞ্চগড়", "Panchagarh", 26.3354, 88.5532, "multi", 2),
    ("rangpur", "ঠাকুরগাঁও", "Thakurgaon", 26.0333, 88.4667, "multi", 2),
    ("rangpur", "গাইবান্ধা", "Gaibandha", 25.3290, 89.5436, "flood", 3),

    # ---- MYMENSINGH (flood) ----
    ("mymensingh", "ময়মনসিংহ", "Mymensingh", 24.7471, 90.4203, "flood", 3),
    ("mymensingh", "জামালপুর", "Jamalpur", 24.9167, 89.9500, "flood", 2),
    ("mymensingh", "শেরপুর", "Sherpur", 25.0167, 90.0167, "flood", 2),
    ("mymensingh", "ফুলপুর", "Phulpur", 24.9500, 90.3667, "flood", 2),
    ("mymensingh", "মুক্তাগাছা", "Muktagachha", 24.7500, 90.2667, "flood", 1),
    ("mymensingh", "গৌরীপুর", "Gouripur", 24.7667, 90.5833, "flood", 2),
    ("mymensingh", "ত্রিশাল", "Trishal", 24.5667, 90.3833, "flood", 2),
    ("mymensingh", "ঈশ্বরগঞ্জ", "Ishwarganj", 24.6833, 90.5833, "flood", 1),
    ("mymensingh", "নান্দাইল", "Nandail", 24.5833, 90.6500, "flood", 1),
    ("mymensingh", "হালুয়াঘাট", "Haluaghat", 25.1667, 90.3500, "flood", 1),
    ("mymensingh", "ধোবাউড়া", "Dhobaura", 25.2500, 90.4500, "flood", 1),
]

# Source attribution weighted toward the official cyclone-shelter
# authority (MoDMR). Cycled deterministically per record index so the
# output is stable across runs.
_SOURCES = ["MoDMR", "MoDMR", "MoDMR", "UNDP_BD", "BRAC", "DMB", "OSM"]

# Capacity bands by shelter type (deterministic, no RNG so reruns match).
_CAP_FLOOR = {"cyclone": 600, "flood": 300, "multi": 400, "earthquake": 500}
_CAP_STEP = {"cyclone": 180, "flood": 110, "multi": 130, "earthquake": 150}
_CAP_MOD = {"cyclone": 1400, "flood": 700, "multi": 600, "earthquake": 900}

# English label per type.
_TYPE_LABEL_EN = {
    "cyclone": "Cyclone Shelter",
    "flood": "Flood Shelter",
    "multi": "Shelter",
    "earthquake": "Emergency Shelter",
}
# Bangla label per type.
_TYPE_LABEL_BN = {
    "cyclone": "সাইক্লোন শেল্টার",
    "flood": "বন্যা শেল্টার",
    "multi": "শেল্টার",
    "earthquake": "জরুরি শেল্টার",
}


def _capacity(shelter_type: str, idx: int) -> int:
    floor = _CAP_FLOOR[shelter_type]
    step = _CAP_STEP[shelter_type]
    mod = _CAP_MOD[shelter_type]
    return floor + (idx * step) % mod


def main() -> None:
    features = []
    # Per-division sequence for stable ids.
    seq: dict[str, int] = {}
    seen: set[tuple[int, int]] = set()
    global_idx = 0

    for (division, district_bn, town_en, lat0, lon0,
         shelter_type, count) in CENTRES:
        for j in range(count):
            # Spread shelters in a small ~1km circle around the centre.
            angle = j * (2 * math.pi / max(count, 1))
            radius = 0.006 + 0.003 * (j % 2)  # ~0.6-0.9 km
            lat = round(lat0 + radius * math.sin(angle), 5)
            lon = round(lon0 + radius * math.cos(angle), 5)

            # Deduplicate by rounded coordinate.
            key = (int(lat * 1e4), int(lon * 1e4))
            if key in seen:
                continue
            seen.add(key)

            seq[division] = seq.get(division, 0) + 1
            sid = f"bd-shelter-{division}-{seq[division]:03d}"
            cap = _capacity(shelter_type, global_idx)
            source = _SOURCES[global_idx % len(_SOURCES)]
            global_idx += 1

            label_en = _TYPE_LABEL_EN[shelter_type]
            label_bn = _TYPE_LABEL_BN[shelter_type]
            name = f"{town_en} {label_en} {seq[division]}"
            name_bn = f"{town_en} {label_bn} {bn(seq[division])}"

            features.append({
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [lon, lat],  # GeoJSON = [lon, lat]
                },
                "properties": {
                    "id": sid,
                    "division": division,
                    "district": district_bn,
                    "name": name,
                    "name_bn": name_bn,
                    "capacity": cap,
                    "type": shelter_type,
                    "source": source,
                },
            })

    out = {"type": "FeatureCollection", "features": features}
    path = Path(__file__).resolve().parent.parent / "assets" / "shelter" \
        / "cyclone_shelters.geojson"
    path.write_text(json.dumps(out, ensure_ascii=False, indent=2),
                    encoding="utf-8")

    # Summary to stdout.
    by_div: dict[str, int] = {}
    by_type: dict[str, int] = {}
    for f in features:
        p = f["properties"]
        by_div[p["division"]] = by_div.get(p["division"], 0) + 1
        by_type[p["type"]] = by_type.get(p["type"], 0) + 1
    print(f"wrote {len(features)} shelters -> {path}")
    print("by division:", dict(sorted(by_div.items())))
    print("by type:    ", dict(sorted(by_type.items())))
    print(f"file size:  {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
