#!/bin/bash
# Start the reproduction container with this ATOM checkout mounted, then
# install ATOM into it. Run from the ATOM root (the directory holding atom/).
#
#   bash atom/benchmarks/blasst/_repro/shell.sh            # interactive
#   bash atom/benchmarks/blasst/_repro/shell.sh <command>  # one-shot
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a; . "$HERE/pins.env"; set +a
[ -d "$PWD/atom" ] || { echo "run this from the ATOM root (no ./atom here)"; exit 1; }
docker image inspect "$IMAGE" >/dev/null 2>&1 || {
  echo "image $IMAGE not built -- run _repro/docker/build.sh first"; exit 1; }

# --device gives the raw driver nodes; --group-add makes them readable. Without
# the groups the files are present and every GPU call fails with permissions.
# MODELS is optional and only needed by the ruler modes.
MOUNTS=(-v "$PWD":/workspace)
[ -n "${MODELS:-}" ] && MOUNTS+=(-v "$MODELS":/models:ro)
[ -n "${RULER_DATA:-}" ] && MOUNTS+=(-v "$RULER_DATA":/ruler:ro)

# -t only when there IS a terminal. Hardcoding -it makes every non-interactive
# use -- CI, sbatch, `shell.sh <cmd>` -- die with "the input device is not a TTY".
TTY_FLAGS=(-i); [ -t 0 ] && TTY_FLAGS=(-i -t)

exec docker run --rm "${TTY_FLAGS[@]}" \
  --device=/dev/kfd --device=/dev/dri \
  --group-add "$(getent group video | cut -d: -f3)" \
  --group-add "$(getent group render | cut -d: -f3 || getent group video | cut -d: -f3)" \
  --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  --network=host --ipc=host --shm-size=64g \
  -e TRITON_HIP_FORCE_CHAIN_DOT_ACROSS_IF=1 \
  -e ATOM_USE_UNIFIED_ATTN=1 -e AITER_LOG_LEVEL=WARNING \
  -e BLASST_BENCH_WARMUP -e BLASST_BENCH_REPEAT \
  -v atom_blasst_aiter:/opt/aiter \
  "${MOUNTS[@]}" -w /workspace "$IMAGE" \
  bash -lc '
    set -e
    # aiter is built HERE, not in the image: its install calls rocminfo, which
    # needs a GPU that `docker build` does not have. The named volume keeps the
    # compiled tree across runs, so only the first entry pays (~3 min); later
    # ones just re-link it into site-packages, which --rm discards each time.
    if [ ! -e /opt/aiter/setup.py ]; then
      echo "first run: staging aiter $(cat /opt/aiter-commit.txt)"
      cp -a /opt/aiter-src/. /opt/aiter/
    fi
    cd /opt/aiter
    AITER_USE_SYSTEM_TRITON=1 PREBUILD_KERNELS=0 GPU_ARCHS="gfx942;gfx950" \
      pip install -q --no-cache-dir --break-system-packages --no-deps \
                  --no-build-isolation -e . >/dev/null
    pip install -q --no-cache-dir --break-system-packages --no-deps -e /workspace >/dev/null
    cd /workspace
    exec "$@"
  ' _ "${@:-bash}"
