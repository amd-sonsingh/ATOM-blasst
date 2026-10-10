#!/bin/bash
# Random-input threshold sweep. No model, no dataset -- run this first.
# Inside the container, from /workspace.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a; . "$HERE/pins.env"; set +a
OUT="${OUT:-_repro_results}"; mkdir -p "$OUT"
# 0.02878 and 0.05756 are the calibrated thresholds at 32K and 16K. They are in
# the sweep on purpose: both elide 0% on random scores, which is the evidence
# for "random inputs are not a proxy for real ones".
python3 -m atom.benchmarks.blasst.bench_unified_attention_blasst \
    --mode random --seqlens "${SEQLENS:-16384}" --shapes "${SHAPES:-32x8}" \
    --thresholds "${THRESHOLDS:-1e-9,0.02878,0.05756,1.0,2.0,4.0}" \
    --csv "$OUT/random.csv"
echo "wrote $OUT/random.csv"
