#!/usr/bin/env python3
"""
Shongjog evaluation harness — retrieval accuracy on the held-out test set.

Runs each query through the KeywordRetriever (replicated in Python) and
measures recall@1 and recall@3 — did the correct topic appear in the
top-k retrieved chunks?

Usage:
    python3 eval/run_eval.py [--report base|finetuned]

Outputs:
    eval/results/<report>.jsonl  — per-query results
    eval/results/<report>_report.md — aggregate report
"""

import json
import argparse
import os
import sys
import re
from pathlib import Path
from datetime import datetime

# ── Paths ──────────────────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parent.parent
CORPUS_PATH = ROOT / "tools" / "corpus.json"
TEST_SET_PATH = ROOT / "eval" / "test_set.json"
RESULTS_DIR = ROOT / "eval" / "results"


# ── Keyword Retriever (Python replication of lib/rag/keyword_retriever.dart) ─
def tokenize(text: str) -> set[str]:
    """Split on non-word characters, lower-case."""
    return set(re.findall(r"[\u0980-\u09FFa-zA-Z]+", text.lower()))


def score_chunk(query_lower: str, query_words: set[str], chunk: dict) -> float:
    """Replicate KeywordRetriever scoring."""
    score = 0.0

    # Strong signal: keywords_bn found in query
    for kw in chunk.get("keywords_bn", []):
        if kw.lower() in query_lower:
            score += 1.0

    # Medium signal: topic word found in query
    topic = chunk.get("topic", "")
    if topic.lower() in query_lower:
        score += 0.5

    # Weak signal: each query word found in chunk text
    chunk_text_lower = chunk.get("text", "").lower()
    for qw in query_words:
        if qw in chunk_text_lower:
            score += 0.1

    return score


def retrieve_top_k(query: str, corpus: list[dict], k: int = 3) -> list[dict]:
    """Return top-k chunks by keyword-overlap score (score > 0 only)."""
    query_lower = query.lower()
    query_words = tokenize(query_lower)

    scored = []
    for chunk in corpus:
        s = score_chunk(query_lower, query_words, chunk)
        if s > 0:
            scored.append({"chunk": chunk, "score": s})

    scored.sort(key=lambda x: x["score"], reverse=True)
    return scored[:k]


# ── Metrics ────────────────────────────────────────────────────────────
def compute_metrics(results: list[dict]) -> dict:
    """Aggregate metrics from per-query results."""
    total = len(results)
    if total == 0:
        return {}

    recall_at_1 = sum(1 for r in results if r["recall_at_1"]) / total
    recall_at_3 = sum(1 for r in results if r["recall_at_3"]) / total
    has_retrieval = sum(1 for r in results if r["retrieved_count"] > 0) / total

    by_category = {}
    for r in results:
        cat = r["category"]
        if cat not in by_category:
            by_category[cat] = {"count": 0, "r1": 0, "r3": 0}
        by_category[cat]["count"] += 1
        if r["recall_at_1"]:
            by_category[cat]["r1"] += 1
        if r["recall_at_3"]:
            by_category[cat]["r3"] += 1

    for cat_data in by_category.values():
        n = cat_data["count"]
        cat_data["recall_at_1"] = cat_data["r1"] / n if n > 0 else 0
        cat_data["recall_at_3"] = cat_data["r3"] / n if n > 0 else 0
        del cat_data["r1"]
        del cat_data["r3"]

    return {
        "total_queries": total,
        "recall_at_1": round(recall_at_1, 3),
        "recall_at_3": round(recall_at_3, 3),
        "retrieval_rate": round(has_retrieval, 3),
        "by_category": by_category,
    }


# ── Report generation ─────────────────────────────────────────────────
def generate_report(metrics: dict, results: list[dict], label: str) -> str:
    lines = [
        f"# Eval Report: {label}",
        f"\nGenerated: {datetime.now().isoformat()}\n",
        "## Aggregate Metrics\n",
        f"| Metric | Value |",
        f"|---|---|",
        f"| Total queries | {metrics['total_queries']} |",
        f"| Recall@1 | {metrics['recall_at_1']:.1%} |",
        f"| Recall@3 | {metrics['recall_at_3']:.1%} |",
        f"| Retrieval rate (any hit) | {metrics['retrieval_rate']:.1%} |\n",
        "## By Category\n",
        f"| Category | Count | Recall@1 | Recall@3 |",
        f"|---|---|---|---|",
    ]

    for cat, data in sorted(metrics["by_category"].items()):
        lines.append(
            f"| {cat} | {data['count']} | "
            f"{data['recall_at_1']:.1%} | {data['recall_at_3']:.1%} |"
        )

    lines.append("\n## Per-Query Details\n")
    lines.append("| ID | Category | Query (first 40 chars) | Expected | Retrieved topics | R@1 | R@3 |")
    lines.append("|---|---|---|---|---|---|---|")

    for r in results:
        query_short = r["query"][:40] + ("…" if len(r["query"]) > 40 else "")
        retrieved_topics = ", ".join(r["retrieved_topics"]) or "—"
        expected = r["expected_topic"] or "—"
        r1 = "✅" if r["recall_at_1"] else "❌"
        r3 = "✅" if r["recall_at_3"] else "❌"
        lines.append(f"| {r['query_id']} | {r['category']} | {query_short} | {expected} | {retrieved_topics} | {r1} | {r3} |")

    # Failure cases
    failures = [r for r in results if not r["recall_at_3"] and r["expected_topic"]]
    if failures:
        lines.append(f"\n## Retrieval Failures ({len(failures)} queries with expected topic not in top-3)\n")
        for r in failures:
            lines.append(f"- **{r['query_id']}** ({r['category']}): expected `{r['expected_topic']}`, got `{', '.join(r['retrieved_topics']) or 'nothing'}`")

    return "\n".join(lines) + "\n"


# ── Main ──────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Run Shongjog eval harness")
    parser.add_argument(
        "--report", default="base", choices=["base", "finetuned"],
        help="Label for this eval run (determines output filenames)",
    )
    args = parser.parse_args()

    # Load corpus and test set
    corpus = json.loads(CORPUS_PATH.read_text(encoding="utf-8"))
    test_set = json.loads(TEST_SET_PATH.read_text(encoding="utf-8"))

    print(f"Loaded {len(corpus)} corpus chunks, {len(test_set)} test queries")

    results = []
    for q in test_set:
        hits = retrieve_top_k(q["query"], corpus, k=3)
        retrieved_topics = [h["chunk"]["topic"] for h in hits]

        expected = q.get("expected_topic")
        recall_1 = bool(expected and retrieved_topics and retrieved_topics[0] == expected)
        recall_3 = bool(expected and expected in retrieved_topics[:3])

        results.append({
            "query_id": q["id"],
            "category": q["category"],
            "query": q["query"],
            "expected_topic": expected,
            "retrieved_topics": retrieved_topics,
            "retrieved_count": len(hits),
            "recall_at_1": recall_1,
            "recall_at_3": recall_3,
            "expected_safety_refusal": q.get("expected_safety_refusal", False),
            "myth_to_correct": q.get("myth_to_correct"),
        })

    # Compute metrics
    metrics = compute_metrics(results)

    # Output
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    jsonl_path = RESULTS_DIR / f"{args.report}.jsonl"
    with jsonl_path.open("w", encoding="utf-8") as f:
        for r in results:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    report_path = RESULTS_DIR / f"{args.report}_report.md"
    report = generate_report(metrics, results, args.report)
    report_path.write_text(report, encoding="utf-8")

    print(f"\nResults: {jsonl_path}")
    print(f"Report:  {report_path}")
    print(f"\nRecall@1: {metrics['recall_at_1']:.1%}  Recall@3: {metrics['recall_at_3']:.1%}")


if __name__ == "__main__":
    main()
