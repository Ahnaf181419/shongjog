#!/usr/bin/env python3
"""Build the static full-text search index for the course site.

REBUILD DISCIPLINE: run after ANY content edit; predeploy.sh does not
auto-run this (v1). A stale index serves stale search results — after
touching any lesson/reference page, run `python3 tools/build_search_index.py`
before the next deploy (and bump the ?v= on the search-index.json fetch in
assets/search.js, per the site's cache-bump convention).

Content set: site/lessons/0*.html, site/lessons/index.html,
site/reference/*.html (includes its index.html), site/index.html.
Output: site/assets/search-index.json — a JSON list of
  {"u": url relative to site root, "t": <title> text,
   "h": [h2/h3 texts], "b": tag-stripped body text}
Script/style/nav blocks and HTML comments are removed before text
extraction; entities are unescaped; whitespace is collapsed.
"""

import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
OUT = SITE / "assets" / "search-index.json"

TITLE = re.compile(r"<title\b[^>]*>(.*?)</title\s*>", re.I | re.S)
HEADING = re.compile(r"<h[23]\b[^>]*>(.*?)</h[23]\s*>", re.I | re.S)
STRIP_BLOCKS = [
    re.compile(r"<script\b.*?</script\s*>", re.I | re.S),
    re.compile(r"<style\b.*?</style\s*>", re.I | re.S),
    re.compile(r"<nav\b.*?</nav\s*>", re.I | re.S),
    re.compile(r"<!--.*?-->", re.S),
]
TAG = re.compile(r"<[^>]+>")
WS = re.compile(r"\s+")


def content_files():
    files = sorted(SITE.glob("lessons/0*.html"))
    files.append(SITE / "lessons" / "index.html")
    files += sorted(SITE.glob("reference/*.html"))
    files.append(SITE / "index.html")
    return files


def clean(fragment):
    """Strip remaining tags, unescape entities, collapse whitespace."""
    return WS.sub(" ", html.unescape(TAG.sub(" ", fragment))).strip()


def index_page(path):
    raw = path.read_text(encoding="utf-8")
    m = TITLE.search(raw)
    title = clean(m.group(1)) if m else path.stem
    text = raw
    for rx in STRIP_BLOCKS:
        text = rx.sub(" ", text)
    return {
        "u": path.relative_to(SITE).as_posix(),
        "t": title,
        "h": [clean(h) for h in HEADING.findall(text)],
        "b": clean(text),
    }


def main():
    pages = [index_page(p) for p in content_files()]
    data = json.dumps(pages, separators=(",", ":"), ensure_ascii=False)
    OUT.write_text(data, encoding="utf-8")
    print(f"{len(pages)} pages, {OUT.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
