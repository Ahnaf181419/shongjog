# Presentation script

Companion to `Shongjog-Exhibition-Deck.pdf` (19 slides).
AUST CSE Carnival 8.0 · Project Exhibition.

---

## How to use this

Judges at an exhibition rarely give you the long version, so **learn the booth
version first** — it is the only one you are guaranteed to get.

| Plan | Talk | Slides | When |
|---|---|---|---|
| **Booth** | ~105 s | 1 · 4 · 5, then straight to the demo | A judge stops at the table |
| **Standard** | ~4 min | 1 · 2 · 4 · 5 · 6, demo, then 14 and 17 if they stay | The normal case |
| **Full** | ~12 min | All 19 | A scheduled slot |

Timings are measured from the actual word counts below at 125 words per minute —
a realistic presenting pace with pauses, not a reading pace. The demo adds about
four minutes on top of any of them.

Slides marked **[skip]** below are the ones to drop first when you are short.

**Say the name correctly:** সংযোগ is *shong-jog*, and it means *connection*.
Lead with the meaning — it lands better than the spelling.

Two presenters work best. **A** carries the story, **B** drives the phone. If you
are three, **C** holds the second and third handsets for the mesh demo and stays
silent until then.

---

## The script

### Slide 1 · Cover — 25 s

> Good morning. This is Shongjog — it's Bangla for *connection*.
>
> It's an emergency assistant for Bangladesh that runs entirely on the phone.
> No internet, no server, no SIM. The whole thing — including a two-and-a-half
> gigabyte AI model — is sitting on the handset in my hand right now.

*Hold up the phone. Do not tap it yet.*

---

### Slide 2 · The problem — 55 s

> Every year floods and cyclones displace millions of people here. And the first
> things to fail are mobile data, broadband and grid power — for hours, sometimes
> days.
>
> So think about what that actually means. Every tool that answers an emergency
> question — every chatbot, every helpline, every translation app — stops working
> at the exact moment the emergency starts. They all fail together, because they
> all fail for the same reason.
>
> The line across this slide is that moment. Above it, help is reachable. Below
> it, you're on your own — and the window below that line, before rescue arrives,
> is when first-aid and safe-water decisions actually save lives.

*The horizon line recurs through the deck. Point at it once, here, and the rest of
the deck reads itself.*

---

### Slide 3 · Why existing tools fall short — 35 s **[skip]**

> There are three failures, and each one forced a design decision.
>
> Cloud tools assume a connection — so we put the model on the device. Leaflets
> and broadcast SMS can't answer *your* situation — so ours takes a spoken
> question and answers that specific question. And a general-purpose LLM will
> confidently invent a dosage — so ours is only allowed to answer from a corpus
> we verified by hand.

---

### Slide 4 · What we built — 35 s

> So: a Flutter app for Android, with Gemma 4 running inside it.
>
> You ask in Bangla, by voice or text. The phone does speech recognition,
> retrieves the relevant verified guidance from a corpus stored on the device,
> generates a step-by-step answer, and reads it back aloud. No server is involved
> at any point in that.
>
> Forty-eight verified corpus chunks. Two hundred and sixty-three cyclone
> shelters. Nine hundred and forty-eight tests passing. Around forty-four
> thousand lines of Dart.

*Don't read the four numbers as a list — say them as evidence that the thing is
real, then move on.*

---

### Slide 5 · A real answer — 45 s

> This is the actual output. Not a mockup — this is a screenshot from the phone
> in airplane mode.
>
> The question was asked in English. The answer comes back in Bangla, because
> that's what the person in the emergency reads.
>
> Three things I want you to notice. Step one is nine-nine-nine — the app sends
> you to human help first, always. The steps are numbered, because nobody parses
> a paragraph in a crisis. And it directly contradicts the folk myth: it says
> keep still, don't cut the wound, don't tie a tourniquet.

*If the judge is in a hurry, stop here and go to the demo.*

---

### Slide 6 · Four ways to answer — 80 s

> Behind that answer there are four tiers, tried in order, each cheaper and more
> certain than the one above.
>
> Tier zero has no model in it at all. "Where is the nearest shelter" is pure
> Dart — a distance calculation over the bundled shelter list. That used to run a
> full language model just to extract one number, which took thirty to fifty
> seconds for the single most urgent question in the app. Taking the AI *out* of
> it made it instant, and it can't invent a shelter that doesn't exist.
>
> Tier one is Gemma on the device — the normal path, and the only one that works
> offline. Tier two is cloud Gemini, but only if there happens to be a network.
> Tier three shows the verified passage word for word, with no generation at all.
> And tier four says plainly that it couldn't answer, and offers nine-nine-nine.
>
> The user always gets something. There is no path where they get an error
> screen.

---

### Slide 7 · Grounding — 45 s **[skip]**

> Here's the part I'd most want a faculty member to push on.
>
> There is no engineering standard that governs AI-generated first aid. So we
> wrote the governance ourselves: a seven-organisation source whitelist — WHO,
> Red Crescent, IFRC, CDC, UNICEF, the disaster management ministry, and the met
> department. Nothing enters the corpus from the open web, and every passage
> carries the document it came from.
>
> Three rules the app cannot break: it answers only from the corpus, it never
> diagnoses or prescribes a dose, and anything past first aid gets routed to a
> hospital or to nine-nine-nine.

---

### Slide 8 · Two models on the handset — 40 s **[skip]**

> There are actually two models on the phone. Gemma 4 E2B does the generation —
> two and a half gigabytes. EmbeddingGemma, a hundred and seventy-nine megabytes,
> does semantic search over the corpus.
>
> One constraint shapes a lot of this: the inference engine only ships native
> libraries for arm64. A universal build would still install on other phones with
> no engine at all and fail in a way that looks exactly like a bug — so we
> restrict the ABI and make that impossible.

---

### Slide 9 · The mesh — 50 s

> And if the towers are down entirely, the phones become the network.
>
> Nearby handsets find each other directly over Wi-Fi Direct and carry text,
> photos, video, voice notes — and full-duplex voice calls, with no cellular
> service at all. An SOS message is re-broadcast by every phone that receives it,
> with a hop limit and a one-hour lifetime so it spreads outward without looping.
>
> I'll show you this working in a moment, and I'd encourage you to try to break
> it.

*Honest limit — say it before they ask:*

> The range is Wi-Fi Direct, so tens of metres. It's for a shelter or a village
> cluster, not a district. We're not claiming otherwise.

---

### Slide 10 · The product — 30 s **[skip]**

> Everything is Bangla-first — it isn't an English app with a translation layer
> bolted on. Twenty-six offline quick cards, a family disaster planner that
> writes a plan for your specific household, and the shelter finder.
>
> The type floors at seventeen points, not Material's fourteen, and tap targets
> at forty-eight. The app is read outdoors, at night, by frightened people.

---

### Slide 11 · The coordinator panel — 45 s **[skip]**

> Survivors aren't the only user. There's a coordinator side: live safe and
> danger counts, the danger list with GPS, campaign approval, and broadcast.
>
> And that broadcast is the highest-consequence control in the product — one
> message becomes a notification on every install. Our security rules file says
> in its own header that the admin gate is client-asserted and non-cryptographic,
> and that it opens a misinformation channel. We wrote that down in the code,
> because a risk you can't remove without a trusted server should at least be
> written where the next developer will read it.

---

### Slide 12 · Architecture, the dependency rule — 40 s **[skip]**

> A hundred and fifty-six Dart files, held together by one rule: the parts that
> have to be correct never touch the framework.
>
> Retrieval, prompt construction, the triage decision tree, shelter ranking —
> that whole layer is pure Dart with zero Flutter imports. Which means the logic
> that decides what a person in an emergency is told can be tested exhaustively
> on a laptop, with no device at all. That's why the test suite can be this big
> and this fast.

---

### Slide 13 · The request path — 50 s

> This is one question travelling end to end.
>
> Left to right: the question comes in, speech to text, a classifier that sets
> the reasoning budget, retrieval over the forty-eight chunks, prompt
> construction — then Gemma, the grounded answer, and text-to-speech.
>
> The blue boxes are pure Dart. The dark one is the native model runtime. And
> the important thing is the line across the top: everything below it runs with
> the radio off. Exactly one arrow crosses that line — the cloud fallback — and
> the app works without it.
>
> Along the bottom is what all of this reads from local storage.

*This is the strongest slide for a technical judge. If they engage here, stay.*

---

### Slide 14 · Evidence — 55 s

> Everything on this slide was re-run this morning.
>
> Nine hundred and forty-eight tests passing, zero failing. Zero analyzer issues.
> And twelve checks that run against the built APK — because both times the
> offline model broke, the analyzer and the tests were completely clean. The
> failure only ever showed up in an installed release build. So the build script
> now inspects the artefact itself and refuses to ship if anything's wrong.

*Then, deliberately:*

> On the right is our retrieval quality, and it's the number that doesn't flatter
> us. Recall-at-one is forty-six percent. We tripled the corpus and it didn't
> move — which tells us the retriever is the bottleneck, not the corpus. That's
> what the on-device semantic search is aimed at.

*Volunteering your weakest number is the single highest-value thing in this talk.
Do not skip it.*

---

### Slide 15 · SDGs — 30 s

> Three goals directly. Eleven-point-five, reducing deaths and people affected by
> disasters — that's the shelters, the SOS relay, the emergency dialer.
> Thirteen-point-one, resilience to climate hazards — twelve hazard types and
> live feeds that keep working after the feeds go dark. And three-point-d, health
> emergency capacity — the verified first-aid corpus and the triage wizard.
>
> Ten, six and nine we'd call supporting rather than central.

*Claiming three strongly beats claiming six weakly. If they push, the other three
are on the slide.*

---

### Slide 16 · Complex Engineering Problem — 35 s

> On the CEP criteria we hit all seven attributes, and each one has something in
> the repository to point at.
>
> The two I'd highlight: P5, outside standards — there is no code governing
> AI-generated first aid, so we wrote the governance. And P2, conflicting
> requirements — offline capability against a two-and-a-half gigabyte model,
> latency against reasoning quality, key security against having no server. The
> whole design is those trade-offs being resolved.

---

### Slide 17 · What we're not claiming — 40 s

> Six things we're not claiming.
>
> Retrieval is our weakest link. The corpus is a demonstration corpus, not
> national coverage — deliberately, because every chunk is hand-verified against
> a cited source and that review is the slow step. The mesh is short-range. The
> admin gate isn't real authentication. It's Android and arm64 only. And our
> Bangla answer-quality evaluation hasn't been signed off by a medical reviewer
> yet — which is why we quote retrieval numbers and not answer-quality numbers.
>
> Please test us on any of those.

---

### Slide 18 · The demo — *transition only, 10 s*

> Let me just show you.

*Go to the demo. Don't read the run-sheet aloud — it's there for you, not them.*

---

### Slide 19 · Close — 15 s

> Guidance that stays reachable after everything else stops.
>
> Next for us: a bigger reviewed corpus, a fine-tuned Bangla adapter, and
> partnerships with the agencies whose guidance the app already cites.
>
> Happy to take questions.

---

## The live demo — word for word

**Total: about 4 minutes.** B drives the phone; A narrates. Rehearse this until
you can do it while talking.

### 0:00 — Establish the conditions

> Before anything else — watch the status bar.

*B turns on airplane mode. Hold the phone up so they see the icon appear. Pause
for two full seconds. This is the most important moment of the demo — don't rush
it.*

> Airplane mode. No mobile data, no Wi-Fi, no SIM. Everything from here on is
> happening on this handset.

### 0:20 — The core question

*B taps the mic and asks aloud, in Bangla:*

> **"সাপে কামড়েছে, কী করবো?"** *(a snake has bitten, what do I do?)*

*While it generates:*

> It's doing speech recognition, retrieval, and generation right now — all
> locally. On this hardware it takes a few seconds.

*When the answer appears:*

> Step one is nine-nine-nine. Then keep the person still, keep the bite below
> heart level, don't cut it, don't tie a tourniquet.

*B taps পড়ুন (read aloud).*

> And it reads it out, for someone who can't read the screen.

### 1:30 — The myth test

> Now watch it handle a dangerous piece of folk knowledge.

*B asks:* **"সাপে কামড়ালে কেটে ফেলা উচিত, তাই না?"** *(you should cut a
snakebite, right?)*

> It contradicts the premise instead of politely going along with it. Ten of our
> fifty evaluation queries are myths phrased exactly like that.

### 2:10 — The no-model path

*B taps the shelter finder.*

> Instant — because there's no model in this path at all. Two hundred and
> sixty-three shelters, ranked by GPS distance, with capacity and the agency that
> listed each one. Still in airplane mode.

### 2:40 — The mesh

*B turns Wi-Fi back on, leaves cellular off. C brings the second handset.*

> Wi-Fi on, cellular still off — so there's still no internet and no carrier.
> These two phones are finding each other directly.

*Send a message between the two phones. Then send an SOS.*

> That's the SOS relay. On a third phone it would re-broadcast, five hops, one
> hour.

### 3:30 — The coordinator side

*C shows the panel on the third handset.*

> And the danger report from that phone is already in the coordinator's live
> list.

### 3:50 — Hand it over

> Would you like to try it? Turn the network off yourself, whenever you want.

*This invitation is worth more than anything you can say. Offer it every time.*

---

## Question bank

Answer in one or two sentences, then stop. The temptation is to keep going.

**"Isn't this just a wrapper around Gemma?"**
> The model is one of four tiers, and it isn't in the most urgent path at all.
> The work is the corpus verification, the fallback design, and getting a 2.5 GB
> model to run reliably on a mid-range handset without being killed by the OS.

**"How do you stop it hallucinating medical advice?"**
> It's constrained to a corpus we verified by hand against named health
> authorities, and it never diagnoses or prescribes a dose. If generation fails
> or comes back empty, it shows the verified passage verbatim instead of
> improvising.

**"Forty-six percent recall isn't very good."**
> Agreed, and it's our weakest link. What it tells us is that the retriever is
> the bottleneck, not the corpus — we tripled the corpus and the number didn't
> move. On-device semantic search is the fix we're building.

**"Who verified the corpus?"**
> Every chunk traces to a document from one of seven organisations — WHO, BDRCS,
> IFRC, CDC, UNICEF, MoDMR, BMD — and goes through a two-person review before it
> ships. We're honest that a Bangla-speaking medical reviewer hasn't signed off
> the generated-answer test set yet.

**"What if the user hasn't downloaded the 2.5 GB model?"**
> Everything except the AI chat works immediately — quick cards, triage wizard,
> shelter map, emergency directory. And if the phone has a network, the chat
> falls through to cloud Gemini until the download finishes.

**"Why Android only? Why not iOS?"**
> The inference engine ships native libraries for arm64 Android. It isn't a
> preference — the model genuinely won't run elsewhere yet. It's also the right
> platform for the users we're targeting.

**"How far does the mesh reach?"**
> Wi-Fi Direct, so tens of metres line-of-sight. Useful inside a shelter or
> across a village cluster, not across a district. We're not claiming otherwise.

**"What about battery? A 2.5 GB model must drain it."**
> It only runs during a query, not continuously, and we open a fresh session per
> query and close it immediately — sharing one leaked memory until the OS killed
> the app. Generation is capped at ninety seconds.

**"Is the user's location being sent anywhere?"**
> Only when they choose to — an SOS message or a danger report includes
> coordinates because a responder needs them. Nothing is transmitted in the
> background, and the core app needs no account at all.

**"How would this scale to millions of users?"**
> Inference is on the device, so there's no per-query server cost — that part
> scales for free. What breaks first is retrieval quality and corpus coverage,
> and both are review-bound, not compute-bound.

**"Isn't the admin panel a security hole?"**
> Yes, and we documented it rather than hiding it. The client-side gate isn't
> real authentication; the meaningful boundary is in the Firestore rules. Fixing
> it properly needs a trusted server, which we don't have.

**"How is this different from the government's disaster apps?"**
> Those need a network to do anything useful. Ours is built for the hours after
> the network dies, which is the window we think is underserved.

**"What did you find hardest?"**
> Making failure invisible to the user. Any tier can fail — the model, the cloud,
> the GPS, ten different feeds — and the person still has to get a useful answer.
> That's most of the design.

**"What would you do with another six months?"**
> Fix retrieval, get the corpus medically reviewed at scale, and put offline
> speech recognition on every device rather than preferring it where available.

---

## Things not to say

- **Don't say "it's basically ChatGPT for disasters."** It invites exactly the
  hallucination question you don't want framed that way.
- **Don't oversell the mesh.** Say the range limit before they ask.
- **Don't quote answer-quality numbers.** The generated-answer test set is marked
  pending medical review. Quote retrieval numbers only.
- **Don't say "we haven't tested that."** Say what you *have* verified, and what
  you'd do next.
- **Don't read the slides.** They can read faster than you can talk.

---

## If something breaks

| What happens | What you say and do |
|---|---|
| Generation takes too long | *"It's a two-and-a-half gigabyte model on a mid-range phone — this is the real latency, not a trick."* Keep talking; don't stare at it. |
| Model isn't loaded | Switch to quick cards or the triage wizard. *"That path has no model in it at all — which is the point of tier zero."* |
| Mesh won't pair | Check **Wi-Fi is on** — the transport is Wi-Fi Direct, not Bluetooth. Both phones need it. Separate them by a metre. |
| A phone dies | Hand over the spare. Never demo on the last working handset. |
| Everything fails | Play the recorded clip. *"Here it is running earlier today — and I'd rather show you the failure honestly than pretend."* |

**Have ready:** three arm64 phones with the model pre-downloaded and permissions
granted, a power bank, a screen-mirror adapter, and the fallback video.

**Never download the model on venue Wi-Fi.** It's 2.47 GB and it will not finish.
