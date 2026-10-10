#!/bin/bash
# Generate the 13 RULER tasks at 32K. Needs network and a tokenizer; run on the
# HOST (or any box with the model), not necessarily inside the container.
#
#   MODEL=/path/to/Qwen3-8B OUT=/data/ruler bash .../gen_ruler_data.sh
set -euo pipefail
: "${MODEL:?set MODEL to the Qwen3-8B directory (used as the tokenizer)}"
OUT="${OUT:?set OUT to where the ruler root should go}"
CTX="${CTX:-32768}"; N="${N:-50}"
SRC="${RULER_SRC:-$PWD/RULER}"
[ -d "$SRC" ] || git clone https://github.com/NVIDIA/RULER "$SRC"
pip install -q -r "$SRC/requirements.txt"
cd "$SRC/scripts/data"   # prepare.py resolves its template paths relative to here
for task in niah_single_1 niah_single_2 niah_single_3 \
            niah_multikey_1 niah_multikey_2 niah_multikey_3 \
            niah_multivalue niah_multiquery vt cwe fwe qa_1 qa_2; do
  echo "=== $task ==="
  python prepare.py --save_dir "$OUT/ctx_$CTX" --benchmark synthetic \
      --task "$task" --tokenizer_path "$MODEL" --tokenizer_type hf \
      --max_seq_length "$CTX" --model_template_type base --num_samples "$N"
done
# Sequence length is counted in the TARGET model's tokens, so data built with
# one tokenizer is not valid for another model.
echo "ruler root: $OUT/ctx_$CTX"
