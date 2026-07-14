# Knowledge Base Authoring

`corpus.json` is a JSON array of chunks. Each chunk has:

- `id` — stable snake_case identifier
- `topic` — one of: water, ors, diarrhea, snakebite, bleeding, cyclone, drowning, fever, infant, emotional
- `lang` — "bn" only for now
- `source` — short citation (e.g. "WHO Cholera FS, 2024", "BDRCS First Aid Guide 2023")
- `text` — the chunk itself in simple Bangla, 60–120 words, written for low-literacy users
- `keywords_bn` — 5–10 Bangla keywords that should match this chunk even with imperfect STT

## Authoring Rules

1. Plain Bangla, no jargon. Class 5 reading level.
2. 60–120 words per chunk.
3. One actionable idea per chunk.
4. Numbered steps for sequential actions.
5. Bangla numerals (০-৯), not Western digits.
6. Danda (।) as full stop.
7. No diagnosis, no prescription.
8. End critical chunks with escalation cue.
9. Source attribution required.
10. Keywords cover STT failure modes.

## Source Whitelist

- WHO (who.int)
- BDRCS (bdrcs.org)
- MoDMR (modmr.gov.bd)
- BMD (bmd.gov.bd)
- CDC (cdc.gov)
- IFRC (ifrc.org)

## Review Process

1. Sehab drafts chunk in corpus.json
2. Add `// REVIEW: <question>` comment where unsure
3. Ahnaf edits Bangla phrasing, checks medical accuracy
4. Ahnaf marks chunk approved (remove // REVIEW comment)
5. Ahnaf runs build_kb.py → assets/kb/{corpus.json, vectors.bin}
6. Ahnaf runs verify_kb.py → all 7 test queries must be OK
7. Commit to main at IC-2
