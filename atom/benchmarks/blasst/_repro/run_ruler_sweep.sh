#!/bin/bash
# The headline sweep: 13 RULER tasks x SAMPLES prompts x all layers at the
# calibrated threshold. SAMPLES defaults to 50 (~2.5 h on one MI355X); set it
# lower for a smoke test. Inside the container, from /workspace.
#
#   RULER_ROOT=/ruler/ctx_32768 MODEL=/models/<snapshot> bash .../run_ruler_sweep.sh
#   SAMPLES=2 RULER_ROOT=... MODEL=... bash .../run_ruler_sweep.sh   # quick check
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a; . "$HERE/pins.env"; set +a
: "${RULER_ROOT:?set RULER_ROOT to the ctx_32768 directory}"
: "${MODEL:?set MODEL to the Qwen3-8B directory}"
OUT="${OUT:-_repro_results/ruler_13x50}"; mkdir -p "$OUT"
TASKS="niah_single_1 niah_single_2 niah_single_3 niah_multikey_1 niah_multikey_2
       niah_multikey_3 niah_multivalue niah_multiquery vt cwe fwe qa_1 qa_2"
echo "threshold=$THRESHOLD warmup=$BLASST_BENCH_WARMUP repeat=$BLASST_BENCH_REPEAT"
for task in $TASKS; do
  csv="$OUT/$task.csv"
  # Resumable. A csv with rows is treated as done -- so if a run was killed
  # mid-task, DELETE that task's csv before resuming: a truncated file is
  # indistinguishable from a complete one here.
  [ -s "$csv" ] && { echo "$task: already has rows, skipping"; continue; }
  echo "=== $task ==="
  python3 -m atom.benchmarks.blasst.bench_unified_attention_blasst \
      --mode ruler --input-file "$RULER_ROOT/$task/validation.jsonl" \
      --model "$MODEL" --ruler-mode full --num-prompts "${SAMPLES:-50}" \
      --thresholds "$THRESHOLD" --csv "$csv" 2>&1 | tail -3
done
python3 "$HERE/aggregate.py" "$OUT"
