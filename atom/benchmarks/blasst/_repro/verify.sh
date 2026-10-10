#!/bin/bash
# Confirm the environment is the one the reference numbers were measured on.
# Run INSIDE the container. Every check has burned us at least once.
set -uo pipefail
rc=0
say() { printf '%-34s %s\n' "$1" "$2"; }

cat /opt/triton-src-commit.txt 2>/dev/null || { echo "no pinned-Triton marker"; rc=1; }
cat /opt/aiter-commit.txt 2>/dev/null || { echo "no pinned-aiter marker"; rc=1; }
echo

python3 - <<'PY' || rc=1
import inspect, os, sys
import triton
assert triton.__version__.startswith("3.8"), f"triton {triton.__version__} is not the pinned build"
print(f"{'triton':<34} {triton.__version__} at {triton.__file__}")

# An IMPORT check, not a file-exists check: aiter ships a sys.meta_path shim, so
# a module can resolve from a path that holds no such file, and vice versa.
import aiter.ops.triton.attention.unified_attention as u
assert "block_skip_threshold" in inspect.signature(u.unified_attention).parameters, \
    "this aiter predates the block-skip API -- rebuild the image"
print(f"{'aiter block_skip_threshold':<34} present")

import atom, torch
print(f"{'atom':<34} {atom.__file__}")
print(f"{'torch':<34} {torch.__version__} (hip {torch.version.hip})")

# ATOM goes in with --no-deps, so its own runtime requirements are installed by
# name in the image. Check them here: the benchmark needs only torch/aiter/
# triton, so a missing one stays invisible until something larger -- the server
# -- runs and dies on an import.
# IMPORT names, not pip names -- pyzmq imports as `zmq`, and checking the pip
# name reports a false missing on a correctly built image.
import importlib.util
missing = [m for m in ("msgspec", "prometheus_client", "fastapi", "uvicorn",
                       "zmq", "uvloop", "xxhash", "psutil")
           if importlib.util.find_spec(m) is None]
print(f"{'atom runtime deps':<34} {'all present' if not missing else 'MISSING ' + ', '.join(missing)}")
if missing:
    raise SystemExit(f"missing ATOM runtime deps: {missing} -- rebuild the image")

flag = os.environ.get("TRITON_HIP_FORCE_CHAIN_DOT_ACROSS_IF")
print(f"{'chain-dot patch active':<34} {flag}")
if flag != "1":
    print("  WARNING: the reference speedups were measured with this set to 1.")
PY

echo
if [ "$rc" -eq 0 ]; then echo "environment OK"; else echo "environment NOT reproducible"; fi
exit $rc
