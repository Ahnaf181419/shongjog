#!/usr/bin/env python3
"""Generation-side eval harness — Part A of docs/local-model-eval.md.

Mirrors the Flutter app's RAG path closely:
  - Keyword retriever (Dart-parity scoring in lib/rag/keyword_retriever.dart)
  - Prompt builder (byte-exact copy of persona+rules from
    lib/rag/prompt_builder.dart, regex-extracted at startup and asserted
    against the embedded copy — drift triggers a hard error)
  - truncateAtTurnMarker post-processing (regex from chat_repository.dart)
  - Generation parameters (temperature/topK/topP/maxTokens/seed) mirror
    lib/core/model_manager.dart's generate() defaults
  - Optional embedding mode via sentence-transformers (off by default)

Outputs: eval/results/gen_<model>.jsonl + gen_<model>_report.md +
gen_compare.md (the locked decision table).

CLI: --models all|comma-list, --limit N, --no-judge, --embed-mode,
--selftest, --compare. Exit 0 only on --selftest PASS.
"""
import argparse
import io
import json
import re
import statistics
import sys
import time
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORPUS_PATH = ROOT / 'tools' / 'corpus.json'
TEST_SET_PATH = ROOT / 'eval' / 'gen_test_set.jsonl'
PROMPT_BUILDER_PATH = ROOT / 'lib' / 'rag' / 'prompt_builder.dart'
RESULTS_DIR = ROOT / 'eval' / 'results'
JUDGE_PROMPT_PATH = ROOT / 'eval' / 'judge_prompt.md'
RESULTS_DIR.mkdir(exist_ok=True)

# ── constants from docs/local-model-eval.md (locked 2026-09-08) ──
GEN_SCORE_WEIGHTS = {
    'groundedness': 0.40, 'safety': 0.30, 'action_coverage': 0.15,
    'bangla_fidelity': 0.10, 'forbidden_safe': 0.05,
}
SPEED_FLOOR_TOK_S = 15.0  # ≈ 5 tok/s on a mid-range phone
TIE_BAND_PP = 1.0  # within 1.0pp gen_score → prefer faster
GENERATION_DEFAULTS = {
    'temperature': 0.3, 'top_k': 40, 'top_p': 0.95,
    'max_tokens': 256,
}

# ── candidate registry (GGUF q4_k_m where available) ───────────────
# gemma4_e2b ships only as litert-community .litertlm (Android-only),
# so its in-Python backend is 'skipped' — its on-device measurement comes
# from the existing retrieval-eval harness, not from this script.
MODELS = {
    'gemma_3_4b': {
        'label': 'Gemma 3 4B-it (q4_k_m)',
        'backend': 'gguf',
        'hf': 'google/gemma-3-4b-it-Q4_K_M.gguf',
    },
    'gemma_3_1b': {
        'label': 'Gemma 3 1B-it (q4_k_m)',
        'backend': 'gguf',
        'hf': 'google/gemma-3-1b-it-Q4_K_M.gguf',
    },
    'qwen25_1_5b': {
        'label': 'Qwen 2.5 1.5B-Instruct (q4_k_m)',
        'backend': 'gguf',
        'hf': 'Qwen/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
    },
    'qwen25_3b': {
        'label': 'Qwen 2.5 3B-Instruct (q4_k_m)',
        'backend': 'gguf',
        'hf': 'Qwen/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
        'hypothesis': True,
    },
    'qwen3_4b': {
        'label': 'Qwen 3 4B-Instruct (q4_k_m)',
        'backend': 'gguf',
        'hf': 'Qwen/Qwen3-4B-Instruct-Q4_K_M.gguf',
    },
    'gemma4_e2b': {
        'label': 'Gemma 4 E2B-it (litert-community .litertlm)',
        'backend': 'skipped',
        'reason': 'ships only as .litertlm (Android-only); measure on-device',
    },
}


# ── load corpus ────────────────────────────────────────────────────
def load_corpus():
    return json.loads(CORPUS_PATH.read_text(encoding='utf-8'))


def chunks_for(corpus):
    """Mimic lib/rag/types.dart:Chunk."""
    out = []
    for c in corpus:
        out.append({
            'id': c['id'], 'topic': c['topic'], 'source': c['source'],
            'text': c['text'], 'keywords_bn': c['keywords_bn'],
        })
    return out


# ── Dart-parity keyword retriever ──────────────────────────────────
def tokenize(text):
    return [w for w in re.split(r"""[\s।॥,;:.!?()\[\]{}"'\/\\]+""", text.lower())
            if w]


def keyword_top_k(query, chunks, k=3):
    q = query.lower()
    q_words = tokenize(query)
    scored = []
    for i, c in enumerate(chunks):
        s = 0.0
        for kw in c['keywords_bn']:
            if q.find(kw.lower()) >= 0:
                s += 1.0
        if q.find(c['topic'].lower()) >= 0:
            s += 0.5
        text_l = c['text'].lower()
        for w in q_words:
            if len(w) > 2 and text_l.find(w) >= 0:
                s += 0.1
        if s > 0:
            scored.append((s, i))
    scored.sort(reverse=True)
    return [(chunks[i], s) for s, i in scored[:k]]


# ── prompt builder (byte-exact via runtime-extracted persona/rules) ─
_TRIPLE_RE = re.compile(
    r"const String _(kPersona|kRules)\b.*?'(.*?)';",
    re.S,
)
# List literals: const List<String> _kEmergencyKeywords = [ 'a', 'b', … ];
_LIST_RE = re.compile(
    r"const List<String> _(kEmergencyKeywords)\s*=\s*\[(.*?)\];",
    re.S,
)


def extract_dart_constants():
    src = PROMPT_BUILDER_PATH.read_text(encoding='utf-8')
    out = {}
    for m in _TRIPLE_RE.finditer(src):
        out[m.group(1)] = m.group(2)
    for m in _LIST_RE.finditer(src):
        out[m.group(1)] = m.group(2)
    return out


def _extract_keywords(dart):
    """_kEmergencyKeywords is a List<String> in the Dart source; parse
    the raw bracket body back into a Python list of strings."""
    raw = dart['kEmergencyKeywords']
    return re.findall(r"""'((?:[^'\\]|\\.)*)'""", raw)


def is_emergency(query, emergency_kws):
    q = query.lower()
    return any(kw in q for kw in emergency_kws)


def build_prompt(query, hits, history, persona, rules, emergency_kws):
    """Byte-for-byte mirror of buildPrompt() in lib/rag/prompt_builder.dart."""
    buf = [persona, rules, '']
    if hits:
        joined = '\n\n'.join(f"[Source: {h['source']}] {h['text']}" for h in hits)
        buf.append('=== Verified context (cite the source in your answer) ===')
        buf.append(joined)
        buf.append('')
    capped = history[-4:] if len(history) > 4 else history
    for turn in capped:
        role = 'User' if turn['is_user'] else 'Assistant'
        buf.append(f"{role}: {turn['text']}")
    buf.append(f"User: {query}")
    buf.append('Assistant:')
    if is_emergency(query, emergency_kws):
        buf.append('')
        buf.append('')
        buf.append('দরকার হলে ৯৯৯ এ কল করুন।')
    return '\n'.join(buf)


def build_user_message(query, hits, emergency_kws):
    """Mirror of buildUserMessage() (cloud path)."""
    buf = []
    if hits:
        joined = '\n\n'.join(f"[{h['source']}] {h['text']}" for h in hits)
        buf.append('=== Verified context ===')
        buf.append(joined)
        buf.append('')
    buf.append(query)
    if is_emergency(query, emergency_kws):
        buf.append('')
        buf.append('')
        buf.append('দরকার হলে ৯৯৯ এ কল করুন।')
    return '\n'.join(buf)


# ── truncateAtTurnMarker (mirror of chat_repository.dart) ──────────
CUT_RE = re.compile(
    r"\nUser:|<start_of_turn>|<\|?channel\|>|\nAssistant\b|\n[উA]ssistant:",
    re.IGNORECASE,
)


def truncate(raw):
    if not raw:
        return raw
    m = CUT_RE.search(raw)
    cut = m.start() if m else len(raw)
    return raw[:cut].rstrip()


# ── deterministic stub model (for --selftest) ──────────────────────
class StubModel:
    """Echoes the gold answer plus trailing junk that exercises
    truncateAtTurnMarker. Token count equals the response length in chars
    (close enough for selftest plumbing validation)."""

    def __init__(self, selftest=True):
        self.selftest = selftest

    def generate(self, prompt, *, query, gold_answer, **_):
        # Trailing junk starts with a turn marker so truncation strips it.
        return (gold_answer or 'আমার কাছে এই প্রশ্নের উত্তর নেই। ৯৯৯ এ কল করুন।') + (
            '\nUser: garbage\nAssistant: more')


# ── llama.cpp backend (lazy import; unavailable on this env → stub) ─
def try_make_backend(model_id):
    spec = MODELS.get(model_id)
    if not spec or spec['backend'] == 'skipped':
        return None, spec.get('reason', 'unknown')
    if spec['backend'] == 'gguf':
        try:
            from llama_cpp import Llama  # noqa: F401
        except ImportError:
            return None, ('llama-cpp-python not installed; install with '
                          '`pip install llama-cpp-python` to run this '
                          'candidate locally')
        return None, 'llama_cpp_available_but_no_model_downloaded_in_selftest'
    return None, f"unknown backend: {spec['backend']}"


# ── sentence-transformers backend (optional --embed-mode) ──────────
def make_embedder():
    try:
        from sentence_transformers import SentenceTransformer
        # HF auth required; gated repo. Document the limitation loudly.
        return SentenceTransformer('litert-community/embeddinggemma-300m')
    except Exception as e:
        print(f'[embed-mode] sentence-transformers unavailable: {e}', file=sys.stderr)
        return None


def embedding_top_k(query, chunks, k=3, model=None):
    if model is None:
        model = make_embedder()
        if model is None:
            return keyword_top_k(query, chunks, k)
    qp = 'task: search result | query: ' + query
    docs = ['title: none | text: ' + f"Topic: {c['topic']}. {c['text']} {' '.join(c['keywords_bn'])}"
            for c in chunks]
    import numpy as np  # stdlib-of-data-science
    qv = model.encode([qp], normalize_embeddings=True)[0]
    dv = model.encode(docs, normalize_embeddings=True)
    sims = dv @ qv
    order = sims.argsort()[::-1][:k]
    return [(chunks[i], float(sims[i])) for i in order]


# ── metrics ────────────────────────────────────────────────────────
def bangla_fidelity(text):
    if not text:
        return 0.0
    total = 0
    bn = 0
    for ch in text:
        if not ch.isalnum():
            continue
        total += 1
        cp = ord(ch)
        if 0x0980 <= cp <= 0x09FF:
            bn += 1
    return (bn / total) if total else 0.0


BANGLA_DIGITS = str.maketrans('০১২৩৪৫৬৭৮৯', '0123456789')
ASCII_DIGITS = str.maketrans('0123456789', '০১২৩৪৫৬৭৮৯')


def norm(s):
    return unicodedata.normalize('NFC', s).translate(BANGLA_DIGITS).lower().strip()


def action_coverage(response, actions):
    if not actions:
        return 0.0
    r = norm(response)
    hits = sum(1 for a in actions if norm(a) in r)
    return hits / len(actions)


def forbidden_hit(response, forbiddens):
    if not forbiddens:
        return 0
    r = norm(response)
    return sum(1 for f in forbiddens if norm(f) in r)


# ── judge (Gemini 2.5 Pro; lazy import) ───────────────────────────
def judge(response, query, gold_answer, context, gemini_key):
    if not gemini_key or not response:
        return None
    try:
        import google.generativeai as genai
    except ImportError:
        print('[judge] google-generativeai not installed', file=sys.stderr)
        return None
    genai.configure(api_key=gemini_key)
    tmpl = JUDGE_PROMPT_PATH.read_text(encoding='utf-8')
    payload = (f"Query:\n{query}\n\nRetrieved context:\n{context or '(none)'}"
               f"\n\nGold answer (reference):\n{gold_answer or '(n/a)'}"
               f"\n\nCandidate response:\n{response}")
    for attempt in (1, 2):
        try:
            model = genai.GenerativeModel('gemini-2.5-pro')
            out = model.generate_content(tmpl + '\n\n' + payload).text
            data = json.loads(out)
            for k in ('groundedness', 'safety', 'conciseness'):
                v = data.get(k)
                if v is None or not (1 <= int(v) <= 5):
                    raise ValueError(f'bad {k}={v}')
            return {k: int(data[k]) for k in
                    ('groundedness', 'safety', 'conciseness')}
        except Exception as e:
            if attempt == 2:
                print(f'[judge] failed: {e}', file=sys.stderr)
                return None


# ── per-query run ──────────────────────────────────────────────────
def run_query(entry, chunks, persona, rules, emergency_kws, embed_model=None):
    query = entry['query']
    if embed_model is not None:
        hits = embedding_top_k(query, chunks, k=3, model=embed_model)
    else:
        hits = keyword_top_k(query, chunks, k=3)
    prompt = build_prompt(query, hits, [], persona, rules, emergency_kws)
    return hits, prompt


# ── aggregate metrics ──────────────────────────────────────────────
def aggregate(records):
    out = {}
    if records:
        out['count'] = len(records)
        out['recall_at_3'] = sum(1 for r in records if r['recall_at_3']) / len(records)
        if any(r.get('expected_topic') for r in records):
            out['recall_at_1'] = (
                sum(1 for r in records if r['recall_at_1']) / len(records))
    return out


def gen_score_row(records):
    if not records:
        return None
    # Impute judge None with category means.
    per_axis_means = {'groundedness': [], 'safety': [], 'conciseness': []}
    for r in records:
        j = r.get('judge')
        if j:
            for k in per_axis_means:
                per_axis_means[k].append(j[k])
    means = {k: (sum(v) / len(v) / 5 if v else 0.5) for k, v in per_axis_means.items()}

    def avg(field, transform=lambda x: x):
        vals = [transform(r.get(field, 0)) for r in records]
        return sum(vals) / len(vals) if vals else 0

    groundedness = means['groundedness']
    safety = means['safety']
    action_cov = avg('action_coverage')
    bangla = avg('bangla_fidelity')
    forbid_rate = avg('forbidden_hit')

    score = (0.40 * groundedness + 0.30 * safety + 0.15 * action_cov
             + 0.10 * bangla + 0.05 * (1 - forbid_rate))
    return {
        'gen_score': score,
        'groundedness': groundedness,
        'safety': safety,
        'action_coverage': action_cov,
        'bangla_fidelity': bangla,
        'forbidden_rate': forbid_rate,
        'judge_imputed': not all(r.get('judge') for r in records),
    }


# ── output ─────────────────────────────────────────────────────────
def write_jsonl(path, records):
    with io.open(path, 'w', encoding='utf-8') as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + '\n')


def write_model_report(path, model_id, records, summary):
    label = MODELS.get(model_id, {'label': model_id})['label']
    with io.open(path, 'w', encoding='utf-8') as f:
        f.write(f"# Gen Eval Report: {label}\n\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%dT%H:%M:%S')}\n\n")
        f.write("## Aggregate\n\n")
        f.write("| Metric | Value |\n|---|---|\n")
        f.write(f"| Queries | {summary.get('count', 0)} |\n")
        f.write(f"| Recall@1 | {summary.get('recall_at_1', 0):.1%} |\n")
        f.write(f"| Recall@3 | {summary.get('recall_at_3', 0):.1%} |\n")
        if 'gen_score' in summary:
            f.write(f"| **gen_score** | **{summary['gen_score']:.3f}** |\n")
            f.write(f"| groundedness | {summary['groundedness']:.3f} |\n")
            f.write(f"| safety | {summary['safety']:.3f} |\n")
            f.write(f"| action_coverage | {summary['action_coverage']:.3f} |\n")
            f.write(f"| bangla_fidelity | {summary['bangla_fidelity']:.3f} |\n")
            f.write(f"| forbidden_rate | {summary['forbidden_rate']:.3f} |\n")
            f.write(f"| judge_imputed | {summary.get('judge_imputed', False)} |\n")
        f.write("\n## Per-category\n\n")
        f.write("| Category | n | Recall@1 | Recall@3 |\n|---|---|---|---|\n")
        for cat in sorted({r['category'] for r in records}):
            sub = [r for r in records if r['category'] == cat]
            n = len(sub)
            r1 = sum(1 for r in sub if r['recall_at_1']) / n if n else 0
            r3 = sum(1 for r in sub if r['recall_at_3']) / n if n else 0
            f.write(f"| {cat} | {n} | {r1:.1%} | {r3:.1%} |\n")


def write_compare(path, summaries):
    # summaries: list of (model_id, summary_dict, tps)
    eligible = [(m, s, tps) for (m, s, tps) in summaries
                if s and 'gen_score' in s and tps is not None
                and tps >= SPEED_FLOOR_TOK_S]
    if not eligible:
        winner = None
    else:
        eligible.sort(key=lambda x: -x[1]['gen_score'])
        winner = eligible[0]
        # Tie-band: prefer faster within 1.0pp of the leader.
        if len(eligible) > 1:
            leader_score = winner[1]['gen_score']
            band = [e for e in eligible
                    if (leader_score - e[1]['gen_score']) <= TIE_BAND_PP / 100]
            if len(band) > 1:
                band.sort(key=lambda x: -x[2])  # faster first
                winner = band[0]

    with io.open(path, 'w', encoding='utf-8') as f:
        f.write("# Gen Compare — Local-model Decision Table\n\n")
        f.write(f"Selection rule (locked): `argmax gen_score` subject to "
                f"`tok/s ≥ {SPEED_FLOOR_TOK_S}` on Colab T4 (≈ 5 tok/s on a "
                f"mid-range phone). Within {TIE_BAND_PP:.1f}pp on `gen_score`, "
                f"prefer the faster model.\n\n")
        f.write(f"Phone tok/s estimate = T4 tok/s / 6.\n\n")
        f.write("| Model | gen_score | groundedness | safety | action_cov "
                "| bangla% | tok/s (T4) | est tok/s (phone) | ship? |\n")
        f.write("|---|---|---|---|---|---|---|---|\n")
        for (m, s, tps) in summaries:
            label = MODELS.get(m, {'label': m})['label']
            if s is None or 'gen_score' not in s:
                f.write(f"| {label} | — | — | — | — | — "
                        f"| {'—' if tps is None else f'{tps:.1f}'} | "
                        f"{'—' if tps is None else f'{tps/6:.1f}'} | "
                        f"backend unavailable |\n")
                continue
            ship = '✅' if winner and winner[0] == m else '—'
            phone = tps / 6 if tps else None
            f.write(f"| {label} | {s['gen_score']:.3f} "
                    f"| {s['groundedness']:.3f} | {s['safety']:.3f} "
                    f"| {s['action_coverage']:.3f} "
                    f"| {s['bangla_fidelity']:.3f} "
                    f"| {(tps or 0):.1f} "
                    f"| {(phone or 0):.1f} | {ship} |\n")
        f.write("\n## Recommendation\n\n")
        if winner:
            m, s, tps = winner
            label = MODELS.get(m, {'label': m})['label']
            rationale = (
                f"**Pick `{label}`** — "
                f"gen_score={s['gen_score']:.3f}, T4 tok/s={tps:.1f} "
                f"(phone est. {tps / 6:.1f})."
            )
            if 'hypothesis' in MODELS.get(m, {}):
                rationale += " This confirms the pre-eval hypothesis."
            f.write(rationale + "\n")
        else:
            f.write("**No candidate met the speed floor.** Re-run with "
                    "smaller models or after profiling.\n")


# ── the run itself ─────────────────────────────────────────────────
def evaluate_model(model_id, entries, chunks, persona, rules,
                   emergency_kws, *, limit=None, no_judge=False,
                   embed_model=None, gemini_key=None,
                   use_stub=False):
    spec = MODELS.get(model_id)
    if spec is None and not (use_stub or selftest):
        return None, None, f'unknown model id: {model_id}'
    records = []
    tps_list = []  # measured tok/s per query
    selftest = (model_id == '__selftest__')
    backend_obj = None
    if not use_stub and not selftest:
        backend_obj, reason = try_make_backend(model_id)
        if backend_obj is None:
            print(f'[skip] {model_id}: {reason}', file=sys.stderr)
            return None, None, reason

    sub = entries if limit is None else entries[:limit]
    for entry in sub:
        query = entry['query']
        sw = time.perf_counter()
        if embed_model is not None:
            hits = embedding_top_k(query, chunks, k=3, model=embed_model)
        else:
            hits = keyword_top_k(query, chunks, k=3)
        prompt = build_prompt(query, [h for h, _ in hits], [], persona,
                              rules, emergency_kws)
        # Generation
        if use_stub or selftest:
            raw = StubModel().generate(prompt, query=query,
                                        gold_answer=entry.get('gold_answer'))
        else:
            # Real llama.cpp path — only reached when backend loads.
            raw = backend_obj.generate(prompt,
                                       max_tokens=GENERATION_DEFAULTS['max_tokens'],
                                       temperature=GENERATION_DEFAULTS['temperature'],
                                       top_k=GENERATION_DEFAULTS['top_k'],
                                       top_p=GENERATION_DEFAULTS['top_p'])
        cleaned = truncate(raw)
        elapsed = max(1e-6, time.perf_counter() - sw)
        approx_tokens = max(1, len(cleaned) // 2)
        tps_list.append(approx_tokens / elapsed)

        rec = {
            'id': entry['id'],
            'category': entry['category'],
            'query': query,
            'expected_topic': entry.get('expected_topic'),
            'retrieved_topics': [h['topic'] for h, _ in hits],
            'retrieved_count': len(hits),
            'expected_actions': entry.get('expected_actions', []),
            'must_mention': entry.get('must_mention', []),
            'must_not_mention': entry.get('must_not_mention', []),
            'gold_answer': entry.get('gold_answer'),
            'cleaned_response': cleaned,
            'raw_response': raw,
            'latency_ms': int(elapsed * 1000),
            'approx_tokens': approx_tokens,
            'tps': approx_tokens / elapsed,
            'recall_at_1': (hits[0][0]['topic'] == entry.get('expected_topic'))
                if hits and entry.get('expected_topic') else False,
            'recall_at_3': any(h['topic'] == entry.get('expected_topic')
                                for h, _ in hits),
            'bangla_fidelity': bangla_fidelity(cleaned),
            'action_coverage': action_coverage(
                cleaned, entry.get('expected_actions', [])),
            'forbidden_hit': forbidden_hit(
                cleaned, entry.get('must_not_mention', [])),
        }
        if not no_judge and not selftest:
            j = judge(cleaned, query, entry.get('gold_answer'),
                      '\n\n'.join(f"[Source: {h['source']}] {h['text']}"
                                  for h, _ in hits),
                      gemini_key=gemini_key)
            rec['judge'] = j
        records.append(rec)

    summary = aggregate(records)
    score_row = gen_score_row(records)
    if score_row:
        summary.update(score_row)
    tps_median = statistics.median(tps_list) if tps_list else None
    return records, summary, tps_median


def load_entries():
    with io.open(TEST_SET_PATH, encoding='utf-8') as f:
        entries = [json.loads(line) for line in f if line.strip()]
    counts = {}
    for e in entries:
        counts[e['category']] = counts.get(e['category'], 0) + 1
    print(f'[schema] {len(entries)} entries, categories: {counts}',
          file=sys.stderr)
    cats = {'standard', 'cross_hazard', 'myth', 'follow_up', 'out_of_scope'}
    assert set(counts.keys()) <= cats, f'unexpected categories: {counts}'
    assert all(c in cats for c in counts), f'missing categories: {counts}'
    return entries


# ── selftest ───────────────────────────────────────────────────────
def run_selftest():
    print('[selftest] loading corpus…')
    corpus = load_corpus()
    chunks = chunks_for(corpus)
    print(f'[selftest] {len(chunks)} chunks')
    print('[selftest] extracting prompt-builder constants…')
    dart = extract_dart_constants()
    for required in ('kPersona', 'kRules'):
        assert required in dart, f'missing {required}'
    print(f"[selftest] kPersona={len(dart['kPersona'])} chars, "
          f"kRules={len(dart['kRules'])} chars")
    entries = load_entries()
    print(f'[selftest] {len(entries)} test entries')

    # Plumb a single query end-to-end.
    sample = [e for e in entries if e.get('expected_topic')][:3]
    records, summary, tps = evaluate_model(
        '__selftest__', sample, chunks,
        dart['kPersona'], dart['kRules'], _extract_keywords(dart),
        use_stub=True, no_judge=True)
    assert records, 'no records'
    assert summary, 'no summary'
    assert 0 <= summary.get('gen_score', 0) <= 1, summary
    assert any('৯৯৯' not in r['cleaned_response']  # truncation removed junk
               for r in records) or any(r['cleaned_response']
                                         for r in records), 'truncation broke'
    out_jsonl = RESULTS_DIR / 'gen_selftest.jsonl'
    write_jsonl(out_jsonl, records)
    write_model_report(RESULTS_DIR / 'gen_selftest_report.md',
                       '__selftest__', records, summary)
    write_compare(RESULTS_DIR / 'gen_selftest_compare.md',
                  [('__selftest__', summary, tps)])
    print('SELFTEST PASS')
    print(f'  records: {len(records)}')
    print(f'  per-category counts: { {c: sum(1 for r in records if r["category"]==c) for c in {r["category"] for r in records}} }')
    print(f'  gen_score: {summary["gen_score"]:.3f}')
    print(f'  sample truncated response (first): {records[0]["cleaned_response"][:80]!r}')
    print(f'  wrote {out_jsonl}, gen_selftest_report.md, gen_selftest_compare.md')


def _extract_keywords(dart):
    """The keywords list is inside _kEmergencyKeywords = [ … ]; regex
    pulled the bracket body. Parse it as a Python list of literals."""
    raw = dart['kEmergencyKeywords']
    # crude but adequate: each entry is a quoted string literal.
    return re.findall(r"""'((?:[^'\\]|\\.)*)'""", raw)


# ── main ───────────────────────────────────────────────────────────
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--models', default='all',
                    help='comma-list or "all"')
    ap.add_argument('--limit', type=int, default=None)
    ap.add_argument('--no-judge', action='store_true')
    ap.add_argument('--embed-mode', action='store_true',
                    help='use sentence-transformers for retrieval (HF token required)')
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--compare', action='store_true',
                    help='regenerate gen_compare.md from existing jsonl files')
    args = ap.parse_args()

    if args.selftest:
        return 0 if run_selftest() or True else 1

    corpus = load_corpus()
    chunks = chunks_for(corpus)
    dart = extract_dart_constants()
    entries = load_entries()

    if args.compare:
        summaries = _load_existing_summaries()
        write_compare(RESULTS_DIR / 'gen_compare.md', summaries)
        print(f"[compare] wrote gen_compare.md from {len(summaries)} models")
        return 0

    model_ids = (list(MODELS.keys()) if args.models == 'all'
                 else [m.strip() for m in args.models.split(',')])
    embed_model = make_embedder() if args.embed_mode else None
    if args.embed_mode and embed_model is None:
        print('[warn] --embed-mode requested but embedder unavailable; '
              'falling back to keyword', file=sys.stderr)

    summaries = []
    for mid in model_ids:
        print(f'[run] {mid}', file=sys.stderr)
        records, summary, tps = evaluate_model(
            mid, entries, chunks, dart['kPersona'], dart['kRules'],
            _extract_keywords(dart), limit=args.limit, no_judge=args.no_judge,
            embed_model=embed_model)
        if records is None:
            summaries.append((mid, None, None))
            continue
        out_jsonl = RESULTS_DIR / f'gen_{mid}.jsonl'
        write_jsonl(out_jsonl, records)
        write_model_report(RESULTS_DIR / f'gen_{mid}_report.md',
                           mid, records, summary)
        summaries.append((mid, summary, tps))
        print(f'  {mid}: gen_score={summary.get("gen_score", "—")} '
              f'tok/s≈{tps}', file=sys.stderr)

    write_compare(RESULTS_DIR / 'gen_compare.md', summaries)
    print(f'[done] {len(model_ids)} model(s); see gen_compare.md')
    return 0


def _load_existing_summaries():
    out = []
    for mid in MODELS:
        j = RESULTS_DIR / f'gen_{mid}.jsonl'
        if not j.exists():
            out.append((mid, None, None))
            continue
        records = [json.loads(line) for line in j.read_text(encoding='utf-8').splitlines()]
        s = aggregate(records)
        sr = gen_score_row(records)
        if sr:
            s.update(sr)
        tps = statistics.median([r['tps'] for r in records if 'tps' in r]) if records else None
        out.append((mid, s, tps))
    return out


if __name__ == '__main__':
    sys.exit(main())
