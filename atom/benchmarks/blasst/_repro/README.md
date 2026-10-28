# BLASST reproduction bundle

Everything needed to rebuild the environment the BLASST numbers were measured
in, and to re-run the measurements. Kept off the feature branch so the review
diff stays on the feature itself.

The benchmark README (`atom/benchmarks/blasst/README.md`) is the entry point and
calls into these; this file is the inventory.

## Files

| file | what it does |
|---|---|
| `pins.env` | every pinned version: aiter PR + commit, Triton commit, threshold, warmup/repeat |
| `docker/Dockerfile` | patched Triton + pinned aiter + ATOM's runtime deps |
| `docker/build.sh` | builds that image |
| `patch/0001-force-chain-dot-across-scf-if.patch` | the Triton change the speedups were measured with |
| `shell.sh` | starts the container, installs aiter + ATOM into it |
| `verify.sh` | asserts you have the pinned environment |
| `run_random.sh` | threshold sweep on random inputs, no model needed |
| `aggregate.py` | reduces the RULER sweep to the headline figure |
| `server_probe.py` | one long-context request through a running server |
| `run_ruler_sweep.sh` | the headline sweep: 13 tasks x `SAMPLES` prompts (default 50) |
| `gen_ruler_data.sh` | generates the 13 RULER tasks (clones RULER, fetches its corpora) |

## Order

Run everything from the **ATOM root** -- the directory that holds `atom/` -- so
the paths below resolve and `shell.sh` can mount the tree. `R` is just a
shorthand for the bundle path from there.

```bash
R=atom/benchmarks/blasst/_repro

# --- on the host ---
bash $R/docker/build.sh                        # ~15 min, Triton from source

# --- inside the container, started by shell.sh ---
# MODELS is mounted read-only at /models; needed for data gen and the ruler sweep.
MODELS=<qwen3-8b-parent-dir> bash $R/shell.sh          # drops you into the container
#   then, from /workspace (the mounted ATOM root):
bash $R/verify.sh                              # confirms the pinned environment
bash $R/run_random.sh                          # no model or dataset needed

# RULER data, once (ruler mode only). Run it in the container: it needs
# transformers (for the tokenizer) plus the light deps it installs itself.
# Needs network -- clones NVIDIA/RULER and downloads its corpora (PaulGraham
# essays, SQuAD, HotpotQA ~60 MB, git-LFS english_words.json). A few minutes.
MODEL=/models/<snapshot_hash> OUT=/workspace/ruler [N=<n>] bash $R/gen_ruler_data.sh   # N=<n> samples/task

RULER_ROOT=/workspace/ruler/ctx_32768 MODEL=/models/<snapshot_hash> \
  [SAMPLES=<n>] bash $R/run_ruler_sweep.sh             # headline sweep; SAMPLES=2 for a smoke test
```

`shell.sh` takes a one-shot command too: `bash $R/shell.sh <cmd>` runs `<cmd>`
in the container and exits, which is how CI and the sweep run unattended.

`run_ruler_sweep.sh` defaults to all 13 tasks x 50 prompts; set `SAMPLES=<n>`
for fewer prompts. It calls `aggregate.py` when it finishes -- run that directly
against the output directory to re-print the summary.

## Re-pinning

Change `pins.env`, rebuild. `AITER_PR_COMMIT` moves whenever the aiter PR takes
review feedback, so a bundle that tracked the branch by name would silently
measure different kernel code from one week to the next. Re-pin deliberately.
