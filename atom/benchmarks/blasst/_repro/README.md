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
| `run_ruler_sweep.sh` | the 13 x 50 headline sweep |
| `gen_ruler_data.sh` | generates the RULER tasks |

## Order

```bash
bash _repro/docker/build.sh                    # ~15 min, Triton from source
bash _repro/shell.sh                           # container, with ATOM installed
bash _repro/verify.sh                          # confirms the pinned environment
bash _repro/run_random.sh                      # no model or dataset needed

MODEL=<qwen3-8b> OUT=<dir> bash _repro/gen_ruler_data.sh      # once, on the host
RULER_ROOT=<dir>/ctx_32768 MODEL=<qwen3-8b> \
  bash _repro/run_ruler_sweep.sh                              # ~2.5 h, resumable
```

`run_ruler_sweep.sh` calls `aggregate.py` when it finishes; run it directly
against the output directory to re-print the summary.

## Re-pinning

Change `pins.env`, rebuild. `AITER_PR_COMMIT` moves whenever the aiter PR takes
review feedback, so a bundle that tracked the branch by name would silently
measure different kernel code from one week to the next. Re-pin deliberately.
