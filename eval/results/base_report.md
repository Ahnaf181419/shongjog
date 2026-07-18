# Eval Report: base

Generated: 2026-07-18T14:22:12.639302

## Aggregate Metrics

| Metric | Value |
|---|---|
| Total queries | 50 |
| Recall@1 | 46.0% |
| Recall@3 | 60.0% |
| Retrieval rate (any hit) | 98.0% |

## By Category

| Category | Count | Recall@1 | Recall@3 |
|---|---|---|---|
| cross_hazard | 10 | 50.0% | 70.0% |
| follow_up | 10 | 50.0% | 80.0% |
| myth | 10 | 60.0% | 80.0% |
| out_of_scope | 10 | 0.0% | 0.0% |
| standard | 10 | 70.0% | 70.0% |

## Per-Query Details

| ID | Category | Query (first 40 chars) | Expected | Retrieved topics | R@1 | R@3 |
|---|---|---|---|---|---|---|
| q01 | standard | আমার বাচ্চার ডায়রিয়া হয়েছে, পরিষ্কার … | ors | ors, diarrhea, heat | ✅ | ✅ |
| q02 | standard | সাপে কামড়েছে, কি করবো? | snakebite | snakebite, snakebite, snakebite | ✅ | ✅ |
| q03 | standard | পানি পরিষ্কার করবে কিভাবে? | water | water, cyclone, hygiene | ✅ | ✅ |
| q04 | standard | শিশু পুকুরে ডুবে গেছে, পানি থেকে তুলেছি,… | drowning | drowning, drowning, ors | ✅ | ✅ |
| q05 | standard | হাত কেটে গেছে, রক্ত পড়ছে, কী করবো? | bleeding | diarrhea, infant, pregnancy | ❌ | ❌ |
| q06 | standard | বাচ্চার অনেক জ্বর, কী করবো? | fever | fever, fever, food | ✅ | ✅ |
| q07 | standard | ঘূর্ণিঝড়ের পর আশ্রয়কেন্দ্রে কী করণীয়? | cyclone | cyclone, pregnancy, livestock | ✅ | ✅ |
| q08 | standard | বন্যার পানি পান করা কি নিরাপদ? | water | cyclone, hygiene, livestock | ❌ | ❌ |
| q09 | standard | বমি হচ্ছে, কী খাবো? | ors | ors, diarrhea, food | ✅ | ✅ |
| q10 | standard | শ্বাসকষ্ট হচ্ছে, কী করবো? | breathing | hygiene, respiratory, drowning | ❌ | ❌ |
| q11 | cross_hazard | বন্যার পর পানি দূষিত, বাচ্চার পেটের সমস্… | water | livestock, food, hygiene | ❌ | ❌ |
| q12 | cross_hazard | ঘূর্ণিঝড়ের পর ক্ষতস্থানে সংক্রমণ, কীভাব… | bleeding | bleeding, hygiene, respiratory | ✅ | ✅ |
| q13 | cross_hazard | বন্যায় সাপের ভয় বেশি, কামড়ালে প্রথমে … | snakebite | snakebite, snakebite, snakebite | ✅ | ✅ |
| q14 | cross_hazard | ডুবে যাওয়ার পর শ্বাস নিতে পারছে না, CPR… | drowning | drowning, drowning, cpr | ✅ | ✅ |
| q15 | cross_hazard | বন্যার পর অনেক দিন জ্বর যাচ্ছে না, কী কর… | fever | food, cyclone, fever | ❌ | ✅ |
| q16 | cross_hazard | গর্ভবতী মহিলা বন্যায় আটকে আছে, পেটে ব্য… | pregnancy | pregnancy, pregnancy, cpr | ✅ | ✅ |
| q17 | cross_hazard | বন্যার পর খাবার নেই, শিশুকে কী খাওয়াবো? | infant | hygiene, livestock, food | ❌ | ❌ |
| q18 | cross_hazard | বৃদ্ধ ব্যক্তি ঘূর্ণিঝড়ে আটকে আছে, ঠান্ড… | elderly | heat, cold, elderly | ❌ | ✅ |
| q19 | cross_hazard | বন্যায় বিদ্যুৎের তার ভেঙে পড়েছে, কেউ শ… | electrical | electrical, cyclone, electrical | ✅ | ✅ |
| q20 | cross_hazard | পানি ছাড়ার পর বাড়িতে ছাঁচ পড়েছে, পরিষ… | mold | hygiene, ors, water | ❌ | ❌ |
| q21 | myth | সাপে কামড়ালে কেটে ফেলা উচিত, তাই না? | snakebite | snakebite, snakebite, snakebite | ✅ | ✅ |
| q22 | myth | কেউ বললো সাপে কামড়ালে পাথর দিয়ে কাটতে … | snakebite | snakebite, snakebite, snakebite | ✅ | ✅ |
| q23 | myth | ডায়রিয়া হলে পানি খাওয়া উচিত নয়, শুনে… | ors | diarrhea, ors, diarrhea | ❌ | ✅ |
| q24 | myth | গুজব: কলেরা হলে পানি খাওয়া মৃত্যুর কারণ… | ors | diarrhea, diarrhea, bleeding | ❌ | ❌ |
| q25 | myth | শুনেছি পুকুরে ডুবে যাওয়ার পর মাটিতে পুঁ… | drowning | drowning, drowning, ors | ✅ | ✅ |
| q26 | myth | জ্বর হলে ভেজা কাপড় দিলে আরও খারাপ হয়, … | fever | hygiene, fever, cold | ❌ | ✅ |
| q27 | myth | রক্ত পড়লে তুলসী পাতা দিলে বন্ধ হয়, শুন… | bleeding | bleeding, diarrhea, pregnancy | ✅ | ✅ |
| q28 | myth | গুজব: বন্যার পানিতে নুন দিলে পান করা নির… | water | cyclone, hygiene, livestock | ❌ | ❌ |
| q29 | myth | শুনেছি শক খেলে পানি ছিটিয়ে দিলে সেরে যা… | electrical | electrical, electrical, water | ✅ | ✅ |
| q30 | myth | গর্ভবতী মহিলার জ্বর হলে যেকোনো ওষুধ খেতে… | pregnancy | pregnancy, pregnancy, food | ✅ | ✅ |
| q31 | out_of_scope | আমার মাথাব্যথা কী কারণে হয়? | — | fever, pregnancy, pregnancy | ❌ | ❌ |
| q32 | out_of_scope | বিয়ের জন্য কোন তারিখ ভালো? | — | electrical, ors, ors | ❌ | ❌ |
| q33 | out_of_scope | আমার ফোনের ব্যাটারি কেন দ্রুত শেষ হয়? | — | ors, ors, water | ❌ | ❌ |
| q34 | out_of_scope | ক্রিকেট খেলার নিয়ম কী? | — | ors, elderly | ❌ | ❌ |
| q35 | out_of_scope | আমার স্বপ্নের অর্থ কী? | — | — | ❌ | ❌ |
| q36 | out_of_scope | কোন ক্যারিয়ার ভালো হবে আমার জন্য? | — | water, ors, ors | ❌ | ❌ |
| q37 | out_of_scope | রান্নার রেসিপি জানতে চাই | — | food, emotional | ❌ | ❌ |
| q38 | out_of_scope | কোথায় ভালো রেস্তোরাঁ আছে? | — | ors, water, diarrhea | ❌ | ❌ |
| q39 | out_of_scope | আবহাওয়া আগামীকাল কেমন থাকবে? | — | emotional | ❌ | ❌ |
| q40 | out_of_scope | আমার নামের অর্থ কী? | — | emotional, elderly | ❌ | ❌ |
| q41 | follow_up | ORS খাওয়ার পরও ডায়রিয়া থামছে না, তারপ… | ors | ors, diarrhea, diarrhea | ✅ | ✅ |
| q42 | follow_up | সাপের বিষ কাটানোর পরেও ব্যথা আছে, এখন কী… | snakebite | pregnancy, fever, pregnancy | ❌ | ❌ |
| q43 | follow_up | পানি ফুটিয়েছি, কতক্ষণ পর খাবো? | water | ors, water, water | ❌ | ✅ |
| q44 | follow_up | CPR দিচ্ছি কিন্তু শ্বাস ফিরছে না, আরও কত… | drowning | cpr, drowning, drowning | ❌ | ✅ |
| q45 | follow_up | রক্ত বন্ধ হয়েছে কিন্তু ক্ষতস্থান দেখতে … | bleeding | bleeding, bleeding, fever | ✅ | ✅ |
| q46 | follow_up | জ্বর কমেছে কিন্তু দুর্বল লাগছে, খাবার কী… | fever | food, cyclone, fever | ❌ | ✅ |
| q47 | follow_up | ঘূর্ণিঝড়ের পর বাড়ি ফিরে গেলে কী নিরাপদ… | cyclone | cyclone, cyclone, emotional | ✅ | ✅ |
| q48 | follow_up | বন্যার পানি নামার পর পানি পান করা কি এখন… | water | cyclone, hygiene, livestock | ❌ | ❌ |
| q49 | follow_up | শিশুকে ORS দিচ্ছি কিন্তু বমি করছে, কীভাব… | ors | ors, diarrhea, infant | ✅ | ✅ |
| q50 | follow_up | সাপে কামড়ানো ব্যক্তিকে হাসপাতালে নিয়ে … | snakebite | snakebite, snakebite, snakebite | ✅ | ✅ |

## Retrieval Failures (10 queries with expected topic not in top-3)

- **q05** (standard): expected `bleeding`, got `diarrhea, infant, pregnancy`
- **q08** (standard): expected `water`, got `cyclone, hygiene, livestock`
- **q10** (standard): expected `breathing`, got `hygiene, respiratory, drowning`
- **q11** (cross_hazard): expected `water`, got `livestock, food, hygiene`
- **q17** (cross_hazard): expected `infant`, got `hygiene, livestock, food`
- **q20** (cross_hazard): expected `mold`, got `hygiene, ors, water`
- **q24** (myth): expected `ors`, got `diarrhea, diarrhea, bleeding`
- **q28** (myth): expected `water`, got `cyclone, hygiene, livestock`
- **q42** (follow_up): expected `snakebite`, got `pregnancy, fever, pregnancy`
- **q48** (follow_up): expected `water`, got `cyclone, hygiene, livestock`
