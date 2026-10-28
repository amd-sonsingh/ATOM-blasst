#!/bin/bash
# Generate the 13 RULER tasks at 32K. Run it inside the repro container (started
# by shell.sh): it needs network, a tokenizer, transformers (already in the
# image), and the light deps it installs itself. N=<n> sets samples per task.
#
#   MODEL=/models/<snapshot> OUT=/workspace/ruler bash .../gen_ruler_data.sh
set -euo pipefail
: "${MODEL:?set MODEL to the Qwen3-8B directory (used as the tokenizer)}"
OUT="${OUT:?set OUT to where the ruler root should go}"
CTX="${CTX:-32768}"; N="${N:-50}"
SRC="${RULER_SRC:-$PWD/RULER}"
[ -d "$SRC" ] || git clone https://github.com/NVIDIA/RULER "$SRC"

# english_words.json (used by cwe) is git-LFS, so a plain clone leaves a 132-byte
# pointer that makes cwe die with a JSONDecodeError. git-lfs is not in the
# container; fetch the real blob straight from GitHub's media endpoint, which
# resolves LFS without the client. Guard on size so a prior good copy is kept.
EW="$SRC/scripts/data/synthetic/json/english_words.json"
if [ "$(wc -c < "$EW" 2>/dev/null || echo 0)" -lt 10000 ]; then
  echo "=== fetching english_words.json (git-LFS; cwe) ==="
  curl -sSL https://media.githubusercontent.com/media/NVIDIA/RULER/main/scripts/data/synthetic/json/english_words.json \
       -o "$EW"
fi

# Do NOT install RULER's own requirements file. It pins vllm==0.5.4,
# transformers==4.44.2, nemo-toolkit[all] etc., which downgrade and break the
# pinned repro container. prepare.py and the two data-download helpers only need
# these light packages on top of the transformers/torch already in the image.
pip install -q wonderwords html2text beautifulsoup4 tqdm
cd "$SRC/scripts/data"   # prepare.py resolves its template paths relative to here

# Fetch the corpora the tasks draw from. Without these only niah_single_1 (the
# one 'noise' task) generates; every essay task (niah_single_2/3, multikey,
# multivalue, multiquery, vt, cwe, fwe) and both qa tasks silently write broken
# output -- prepare.py still exits 0, so the failure surfaces only at sweep time.
if [ ! -s synthetic/json/PaulGrahamEssays.json ]; then
  echo "=== fetching PaulGraham essays (essay haystack) ==="
  ( cd synthetic/json && python3 download_paulgraham_essay.py )
fi
if [ ! -s synthetic/json/squad.json ] || [ ! -s synthetic/json/hotpotqa.json ]; then
  echo "=== fetching SQuAD + HotpotQA (qa_1 / qa_2) ==="
  ( cd synthetic/json && bash download_qa_dataset.sh )
fi

for task in niah_single_1 niah_single_2 niah_single_3 \
            niah_multikey_1 niah_multikey_2 niah_multikey_3 \
            niah_multivalue niah_multiquery vt cwe fwe qa_1 qa_2; do
  echo "=== $task ==="
  python3 prepare.py --save_dir "$OUT/ctx_$CTX" --benchmark synthetic \
      --task "$task" --tokenizer_path "$MODEL" --tokenizer_type hf \
      --max_seq_length "$CTX" --model_template_type base --num_samples "$N"
done
# Sequence length is counted in the TARGET model's tokens, so data built with
# one tokenizer is not valid for another model.
echo "ruler root: $OUT/ctx_$CTX"
