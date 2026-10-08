#!/usr/bin/env python3
"""Check docs/reverse/evidence.yml for referential integrity, and report on it.

The point of this is that the database cannot rot silently. A claim that cites a
decompiled file which does not exist, or that quietly loses its confidence, or
whose id is duplicated, is a claim nobody can trust. So:

  * every evidence[].ref that looks like a repo path must exist
  * claim and question ids must be unique and well-formed
  * required fields must be present
  * enum fields must be in range
  * `affected` globs must match at least one file
  * related-claim references must resolve

Exits non-zero on any error. With --report it prints the state of the database:
counts by area and status, and - the number that matters right now - how many
presentation calls the port drops on an unproven assumption.

Usage:
    python tools/validate_evidence.py [--report] [--quiet]
"""

from __future__ import annotations

import argparse
import fnmatch
import os
import sys
import zipfile
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.stderr.write(
        "PyYAML is not installed. Run:  python -m pip install -r requirements.txt\n"
    )
    raise SystemExit(2)

REPO = Path(__file__).resolve().parent.parent
DB = REPO / "docs" / "reverse" / "evidence.yml"
ASSETS = REPO / "game" / "Assets.zip"
ASSET_PREFIX = "game/Assets.zip!"

SUPPORTED_SCHEMA = 1

AREAS = {
    "board", "mana", "combat", "spells", "status_effects",
    "items", "ai", "score", "ui", "render", "save", "campaign",
}
VERDICTS = {"mechanic", "presentation"}
STATUSES = {"recovered", "inferred", "assumed", "refuted", "open"}
CONFIDENCES = {"high", "medium", "low"}
CLAIM_FIELDS = {"id", "title", "area", "verdict", "status", "confidence", "summary"}
QUESTION_FIELDS = {"id", "question", "why_it_matters", "status"}
DECISION_FIELDS = {"id", "decision", "rationale"}
EVIDENCE_KINDS = {"decompiled", "lua", "xml", "constant", "binary", "code", "doc"}


class Problems:
    def __init__(self) -> None:
        self.items: list[str] = []

    def add(self, where: str, msg: str) -> None:
        self.items.append(f"{where}: {msg}")

    def __len__(self) -> int:
        return len(self.items)


def ref_exists(ref: str, problems: Problems, where: str) -> bool:
    """A ref is a repo path, optionally a path inside the assets zip, or a bare
    address. Addresses are not checkable and are allowed."""
    if not ref or ref.startswith("0x"):
        return True
    if ref.startswith(ASSET_PREFIX):
        inner = ref[len(ASSET_PREFIX):]
        if not ASSETS.exists():
            problems.add(where, f"cites {ref} but {ASSETS.name} is missing")
            return False
        with zipfile.ZipFile(ASSETS) as z:
            if inner not in z.namelist():
                problems.add(where, f"cites {inner}, which is not in {ASSETS.name}")
                return False
        return True
    path = REPO / ref
    if path.exists():
        return True
    problems.add(where, f"cites {ref}, which does not exist")
    return False


def glob_matches(pattern: str) -> bool:
    """True if the glob matches anything in the repo."""
    if any(ch in pattern for ch in "*?["):
        for root, _dirs, files in os.walk(REPO):
            if ".git" in root or "_build" in root:
                continue
            for f in files:
                rel = os.path.relpath(os.path.join(root, f), REPO).replace("\\", "/")
                if fnmatch.fnmatch(rel, pattern):
                    return True
        return False
    return (REPO / pattern).exists()


def check_enum(node: dict, field: str, allowed: set[str], problems: Problems, where: str) -> None:
    if field not in node:
        return
    val = node[field]
    if val not in allowed:
        problems.add(where, f"{field}={val!r} is not one of {sorted(allowed)}")


def check_claims(claims: list, problems: Problems) -> dict:
    seen: dict[str, int] = {}
    stats = {"by_area": {}, "by_status": {}, "by_verdict": {}, "mechanic_low_conf": []}

    for idx, c in enumerate(claims):
        cid = c.get("id", f"<claim #{idx}>")
        where = f"claim {cid}"

        missing = CLAIM_FIELDS - set(c)
        if missing:
            problems.add(where, f"missing {sorted(missing)}")

        if cid in seen:
            problems.add(where, f"duplicate id, also at index {seen[cid]}")
        else:
            seen[cid] = idx

        check_enum(c, "area", AREAS, problems, where)
        check_enum(c, "verdict", VERDICTS, problems, where)
        check_enum(c, "status", STATUSES, problems, where)
        check_enum(c, "confidence", CONFIDENCES, problems, where)

        # The rule that makes the presentation audit countable.
        if c.get("verdict") == "presentation":
            if "audited" not in c:
                problems.add(where, "verdict=presentation needs an `audited` field")
            elif c["audited"] is False and c.get("status") == "recovered":
                problems.add(where, "audited=false but status=recovered; it was not audited")

        # A claim with no evidence and no `assumed` status is a claim with nothing
        # behind it, which is how the inverted expiry rule hardened.
        ev = c.get("evidence", [])
        if not ev and c.get("status") not in ("assumed", "open"):
            problems.add(where, f"status={c.get('status')!r} with no evidence")

        for j, e in enumerate(ev or []):
            ew = f"{where} evidence[{j}]"
            if "ref" not in e:
                problems.add(ew, "no `ref`")
                continue
            check_enum(e, "kind", EVIDENCE_KINDS, problems, ew)
            ref_exists(e["ref"], problems, ew)

        for pat in c.get("affects", []) or []:
            if not glob_matches(pat):
                problems.add(where, f"affects {pat}, which matches nothing")

        stats["by_area"][c.get("area", "?")] = stats["by_area"].get(c.get("area", "?"), 0) + 1
        stats["by_status"][c.get("status", "?")] = stats["by_status"].get(c.get("status", "?"), 0) + 1
        stats["by_verdict"][c.get("verdict", "?")] = stats["by_verdict"].get(c.get("verdict", "?"), 0) + 1
        if c.get("verdict") == "mechanic" and c.get("confidence") in ("low", "medium"):
            stats["mechanic_low_conf"].append(cid)

    return stats


def check_questions(questions: list, claim_ids: set[str], problems: Problems) -> None:
    seen: set[str] = set()
    for idx, q in enumerate(questions):
        qid = q.get("id", f"<question #{idx}>")
        where = f"question {qid}"
        missing = QUESTION_FIELDS - set(q)
        if missing:
            problems.add(where, f"missing {sorted(missing)}")
        if qid in seen:
            problems.add(where, "duplicate id")
        seen.add(qid)
        check_enum(q, "status", STATUSES, problems, where)
        for rel in q.get("related", []) or []:
            if rel not in claim_ids:
                problems.add(where, f"related to {rel}, which is not a claim id")


def check_decisions(decisions: list, problems: Problems) -> None:
    seen: set[str] = set()
    for idx, d in enumerate(decisions):
        did = d.get("id", f"<decision #{idx}>")
        where = f"decision {did}"
        missing = DECISION_FIELDS - set(d)
        if missing:
            problems.add(where, f"missing {sorted(missing)}")
        if did in seen:
            problems.add(where, "duplicate id")
        seen.add(did)
        sup = d.get("supersedes")
        if sup is not None and not isinstance(sup, str):
            problems.add(where, f"supersedes={sup!r} is not a decision id or null")


def report(doc: dict, stats: dict, claims: list, questions: list, decisions: list) -> None:
    unaudited = [c["id"] for c in claims
                 if c.get("verdict") == "presentation" and c.get("audited") is False]
    assumed = [c["id"] for c in claims if c.get("status") == "assumed"]
    open_c = [c["id"] for c in claims if c.get("status") == "open"]
    # Refuted questions count too. A question answered "no, it is fine" is the most
    # valuable kind of entry: it is what stops the same worry being re-derived.
    refuted = ([("claim " + c["id"]) for c in claims if c.get("status") == "refuted"]
               + [("question " + q["id"]) for q in questions if q.get("status") == "refuted"])
    resolved_q = [q["id"] for q in questions if q.get("status") == "refuted"]

    def table(title: str, pairs: list[tuple[str, int]]) -> None:
        print(f"\n{title}")
        for k, v in sorted(pairs, key=lambda kv: (-kv[1], kv[0])):
            print(f"  {v:4}  {k}")

    print("=" * 68)
    print("reverse evidence database")
    print("=" * 68)
    table("claims by verdict", list(stats["by_verdict"].items()))
    table("claims by status", list(stats["by_status"].items()))
    table("claims by area", list(stats["by_area"].items()))

    print(f"\n{len(claims)} claims, {len(questions)} open questions, "
          f"{len(decisions)} port decisions")

    print(f"\nMECHANIC claims below high confidence ({len(stats['mechanic_low_conf'])}):")
    for cid in sorted(stats["mechanic_low_conf"]):
        print(f"  - {cid}")

    print(f"\nPRESENTATION calls dropped on an UNPROVEN assumption ({len(unaudited)}):")
    for cid in sorted(unaudited):
        print(f"  - {cid}")
    if not unaudited:
        print("  (none - every presentation claim has been decompiled)")

    print(f"\nclaims with status=assumed ({len(assumed)}):")
    for cid in sorted(assumed):
        print(f"  - {cid}")

    print(f"\nclaims with status=open ({len(open_c)}):")
    for cid in sorted(open_c):
        print(f"  - {cid}")

    print(f"\nSETTLED by evidence, kept so they are not re-derived ({len(refuted)}):")
    for cid in sorted(refuted):
        print(f"  - {cid}")
    if not refuted:
        print("  (none - an empty list usually means nobody looked hard enough)")

    open_q = [q["id"] for q in questions if q.get("status") == "open"]
    print(f"\nopen questions ({len(open_q)}):")
    for qid in sorted(open_q):
        print(f"  - {qid}")
    if resolved_q:
        print(f"\nopen questions since answered ({len(resolved_q)}):")
        for qid in sorted(resolved_q):
            print(f"  - {qid}")

    print()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--report", action="store_true", help="print counts and risk lists")
    ap.add_argument("--quiet", action="store_true", help="errors only")
    args = ap.parse_args()

    if not DB.exists():
        sys.stderr.write(f"missing {DB}\n")
        return 2

    doc = yaml.safe_load(DB.read_text(encoding="utf-8")) or {}
    problems = Problems()

    schema = doc.get("schema")
    if schema != SUPPORTED_SCHEMA:
        problems.add("database", f"schema is {schema!r}, this validator understands "
                                 f"{SUPPORTED_SCHEMA}")

    claims = doc.get("claims") or []
    questions = doc.get("open_questions") or []
    decisions = doc.get("port_decisions") or []

    if not isinstance(claims, list) or not isinstance(questions, list) \
            or not isinstance(decisions, list):
        sys.stderr.write("claims, open_questions and port_decisions must be lists\n")
        return 2

    stats = check_claims(claims, problems)
    claim_ids = {c.get("id") for c in claims if c.get("id")}
    check_questions(questions, claim_ids, problems)
    check_decisions(decisions, problems)

    if problems.items:
        print(f"{len(problems)} problem(s) in evidence.yml:\n", file=sys.stderr)
        for p in problems.items:
            print(f"  {p}", file=sys.stderr)
        return 1

    if args.report and not args.quiet:
        report(doc, stats, claims, questions, decisions)
    elif not args.quiet:
        print(f"evidence.yml OK: {len(claims)} claims, {len(questions)} open questions, "
              f"{len(decisions)} port decisions")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())