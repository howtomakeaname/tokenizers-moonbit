#!/usr/bin/env python3
"""Archive and compare full benchmark runs for cross-version trend tracking.

The benchmark JSON produced by bench_compare.py is a point-in-time snapshot.
This tool keeps a local, git-ignored history of those snapshots and reports
regressions between two runs so a perf change can be evaluated against a
baseline instead of a single noisy number.

Subcommands:
  save <report.json> [--note TEXT]
      Copy a report into reports/trend/ under a timestamped, versioned name
      and refresh reports/trend/latest.json.
  list
      Show archived snapshots.
  compare <old.json> <new.json> [--threshold RATIO] [--abs-threshold RATIO]
      Print rows whose Moon/HF ratio worsened by more than `threshold`
      (default 1.20, i.e. 20% slower relative to HF) AND whose absolute
      Moon time also grew by `abs-threshold` (default 1.15). The second
      condition filters false alarms where only the HF baseline fluctuated
      while Moon time stayed flat. Exit non-zero when regressions exist.
  latest
      Print the path of the most recent archived snapshot.

The trend directory is git-ignored on purpose: benchmarks are machine- and
load-sensitive and do not belong in the source tree. CI nightly runs upload
the same JSON as a build artifact instead.
"""
import argparse
import json
import os
import shutil
import sys
from datetime import datetime, timezone

ROOT = os.path.join(os.path.dirname(__file__), "..")
TREND_DIR = os.path.join(ROOT, "reports", "trend")
LATEST = os.path.join(TREND_DIR, "latest.json")
INDEX = os.path.join(TREND_DIR, "index.json")


def _load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _read_meta(report):
    """Extract stable identity fields from a bench_compare report."""
    return {
        "target": report.get("target"),
        "corpora": report.get("corpora"),
        "models": len(report.get("models", [])),
        "rows": len(report.get("rows", [])),
        "passed": report.get("passed"),
    }


def cmd_save(args):
    report = _load(args.report)
    os.makedirs(TREND_DIR, exist_ok=True)
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    target = report.get("target", "unknown")
    # Version comes from moon.mod at archive time when available.
    version = ""
    moon_mod = os.path.join(ROOT, "moon.mod")
    if os.path.exists(moon_mod):
        for line in open(moon_mod, encoding="utf-8"):
            if line.startswith("version"):
                version = line.split("=", 1)[1].strip().strip('"')
                break
    name = f"{ts}_{target}_v{version}.json" if version else f"{ts}_{target}.json"
    dest = os.path.join(TREND_DIR, name)
    shutil.copyfile(args.report, dest)
    shutil.copyfile(args.report, LATEST)

    index = []
    if os.path.exists(INDEX):
        index = json.load(open(INDEX, encoding="utf-8"))
    entry = {"file": name, "saved_utc": ts, "version": version,
             "note": args.note or "", **_read_meta(report)}
    index.append(entry)
    with open(INDEX, "w", encoding="utf-8") as f:
        json.dump(index, f, indent=2)
    print(f"archived {dest}")
    print(f"latest   {LATEST}")


def cmd_list(_args):
    if not os.path.exists(INDEX):
        print("no snapshots yet; run `save` first")
        return
    for e in json.load(open(INDEX, encoding="utf-8")):
        note = f"  {e['note']}" if e.get("note") else ""
        print(f"{e['saved_utc']}  {e.get('version', '?'):8s} "
              f"{e.get('target', '?'):8s} rows={e.get('rows', 0)}{note}  "
              f"{e['file']}")


def cmd_latest(_args):
    if os.path.exists(LATEST):
        print(LATEST)
    else:
        print("no latest snapshot", file=sys.stderr)
        sys.exit(1)


def cmd_compare(args):
    old = _load(args.old)
    new = _load(args.new)
    old_rows = {r["name"]: r for r in old["rows"]}
    new_rows = {r["name"]: r for r in new["rows"]}
    shared = sorted(set(old_rows) & set(new_rows))
    if not shared:
        print("no shared benchmark rows between the two reports", file=sys.stderr)
        sys.exit(2)

    regressions = []
    noisy = []
    improvements = []
    for name in shared:
        o, n = old_rows[name], new_rows[name]
        # Relative worsening against HF: new ratio / old ratio. >1 means the
        # Moon side got slower relative to the HF baseline.
        if o["ratio"] <= 0 or o["moon_us"] <= 0:
            continue
        factor = n["ratio"] / o["ratio"]
        abs_factor = n["moon_us"] / o["moon_us"]
        if factor >= args.threshold:
            # Require a real absolute slowdown too, otherwise HF-side timing
            # jitter on an unchanged Moon row gets reported as a regression.
            if abs_factor >= args.abs_threshold:
                regressions.append((factor, name, o, n))
            else:
                noisy.append((factor, name, o, n))
        elif factor <= 1.0 / args.threshold:
            improvements.append((factor, name, o, n))

    print(f"compared {len(shared)} shared rows "
          f"({os.path.basename(args.old)} -> {os.path.basename(args.new)})")
    print(f"regression threshold: ratio worsened >= {args.threshold:.2f}x "
          f"and moon time grew >= {args.abs_threshold:.2f}x\n")
    if regressions:
        print(f"REGRESSIONS ({len(regressions)}):")
        for factor, name, o, n in sorted(regressions, reverse=True):
            print(f"  {factor:5.2f}x  {name:42s} "
                  f"{o['ratio']:6.2f} -> {n['ratio']:6.2f} "
                  f"(moon {o['moon_us']:.1f}us -> {n['moon_us']:.1f}us)")
    else:
        print("regressions: none")
    if noisy:
        print(f"\nratio-only fluctuations, not counted (moon time flat, "
              f"{len(noisy)}):")
        for factor, name, o, n in sorted(noisy, reverse=True)[:5]:
            print(f"  {factor:5.2f}x  {name:42s} "
                  f"moon {o['moon_us']:.1f}us -> {n['moon_us']:.1f}us")
    if improvements:
        print(f"\nimprovements ({len(improvements)}), top 10:")
        for factor, name, o, n in sorted(improvements)[:10]:
            print(f"  {factor:5.2f}x  {name:42s} "
                  f"{o['ratio']:6.2f} -> {n['ratio']:6.2f}")

    verdicts = {}
    for r in new["rows"]:
        verdicts[r["verdict"]] = verdicts.get(r["verdict"], 0) + 1
    print(f"\nnew report verdicts: {verdicts}")
    print(f"new report failures: {len(new.get('failures', []))} "
          f"skipped: {len(new.get('skipped_hf_baselines', []))}")
    # Non-zero exit when regressions exist so CI can gate on it.
    sys.exit(1 if regressions else 0)


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("save", help="archive a benchmark report")
    s.add_argument("report")
    s.add_argument("--note", default="")
    s.set_defaults(func=cmd_save)

    sub.add_parser("list", help="list archived snapshots").set_defaults(
        func=cmd_list)
    sub.add_parser("latest", help="print latest snapshot path").set_defaults(
        func=cmd_latest)

    c = sub.add_parser("compare", help="compare two reports")
    c.add_argument("old")
    c.add_argument("new")
    c.add_argument("--threshold", type=float, default=1.20,
                   help="ratio worsening factor that counts as regression")
    c.add_argument("--abs-threshold", type=float, default=1.15,
                   help="required absolute Moon time growth factor")
    c.set_defaults(func=cmd_compare)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
