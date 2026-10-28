#!/usr/bin/env python3
"""Aggregate the RULER sweep into the headline figure.

The headline is a ratio of SUMMED times, not a mean of per-row speedups: a mean
would weight a cheap layer the same as an expensive one.
"""
import csv, glob, os, sys

out = sys.argv[1] if len(sys.argv) > 1 else "_repro_results/ruler_13x50"
files = sorted(glob.glob(os.path.join(out, "*.csv")))

# The bench writes one csv per task and keys rows by `case` (which carries the
# prompt/layer, not the task). The task is the file stem -- run_ruler_sweep.sh
# writes `<task>.csv`. Tag each row with it here so the per-task breakdown and
# the task count work without the bench having to repeat the task on every row.
rows = []
for f in files:
    task = os.path.splitext(os.path.basename(f))[0]
    for r in csv.DictReader(open(f)):
        r["task"] = task
        rows.append(r)
if not rows:
    sys.exit(f"no csv rows under {out}")

el = [float(r["tile_elide"]) for r in rows if r["tile_elide"] not in ("", "nan")]
tasks = {r["task"] for r in rows}
speedup = sum(float(r["dense_ms"]) for r in rows) / sum(float(r["ms"]) for r in rows)

# 13 tasks x 50 prompts x 36 layers. Print the expectation beside the count:
# the glob takes every csv in the directory, so an aggregate written back here
# would silently double every total.
print(f"files {len(files)}  rows {len(rows)} (expect 23400)  tasks {len(tasks)} (expect 13)")
print(f"speedup        {speedup:.4f}x")
print(f"tile elision   {sum(el)/len(el):.1%} mean (min {min(el):.1%}, max {max(el):.1%})")
print()
print(f"{'task':<18}{'speedup':>10}{'elision':>10}")
by = {}
for r in rows:
    by.setdefault(r["task"], []).append(r)
for t in sorted(by):
    rr = by[t]
    sp = sum(float(x["dense_ms"]) for x in rr) / sum(float(x["ms"]) for x in rr)
    e = [float(x["tile_elide"]) for x in rr if x["tile_elide"] not in ("", "nan")]
    print(f"{t:<18}{sp:>9.4f}x{sum(e)/len(e):>9.1%}")
