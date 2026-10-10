# ATOM + BLASST reproduction image.
#
# Bakes the two dependencies that are NOT in any released package:
#
#   1. Triton pinned to TRITON_COMMIT with the chain-dot-across-if patch. The
#      block-skip branch puts the P@V dot inside an `scf.if`, and Triton's
#      chain-dot detection is region-local, so it stops firing there and the dot
#      gets a different warp layout from the dense path. The patch forces it
#      across the `if`. It is NOT upstream, and the reference speedups were
#      measured with it active (TRITON_HIP_FORCE_CHAIN_DOT_ACROSS_IF=1).
#
#   2. aiter carrying `block_skip_threshold` on unified_attention, fetched from
#      the pull-request ref because it is unmerged. Without it ATOM's call
#      raises TypeError on an unexpected keyword -- the benchmark cannot run at
#      all, it does not merely report different numbers.
#
# ATOM itself is NOT baked: it is the thing under review, so it is installed
# from the mounted checkout at run time.
FROM rocm/atom-dev:latest
ENV MAX_JOBS=16

ARG TRITON_REPO
ARG TRITON_COMMIT
ARG AITER_REPO
ARG AITER_PR
ARG AITER_PR_COMMIT

COPY 0001-force-chain-dot-across-scf-if.patch /opt/

# --- patched Triton -------------------------------------------------------
# Remove every Triton distribution first: the ROCm wheels ship under several
# names and leaving one installed shadows the source build at import time.
RUN set -eux; \
    python3 -c "import triton, torch; print('before:', triton.__version__, torch.__version__)"; \
    pip uninstall -y --break-system-packages \
        triton pytorch-triton pytorch-triton-rocm triton-rocm amd-triton || true; \
    pip install --no-cache-dir --break-system-packages ninja cmake 'nanobind==2.10.2'; \
    git clone "$TRITON_REPO" /opt/triton-src; \
    cd /opt/triton-src; \
    git checkout "$TRITON_COMMIT"; \
    git apply /opt/0001-force-chain-dot-across-scf-if.patch; \
    git rev-parse HEAD > /opt/triton-src-commit.txt; \
    echo "patched: 0001-force-chain-dot-across-scf-if.patch" >> /opt/triton-src-commit.txt; \
    pip install --no-cache-dir --break-system-packages -e . --no-build-isolation; \
    python3 -c "import triton; assert triton.__version__.startswith('3.8'), triton.__version__; \
                print('triton:', triton.__version__)"; \
    python3 -c "import torch; assert torch.version.hip is not None, \
                'the Triton swap replaced the ROCm torch build'; print('torch ok')"

# --- aiter from the unmerged PR, cloned but NOT built ------------------
# The build deliberately stops at the clone. aiter's install path calls
# get_gfx_runtime(), which shells out to `rocminfo` and ignores GPU_ARCHS by
# design -- and `docker build` has no GPU, so it dies with "No gfx arch found
# in rocminfo output." The install therefore happens at container start, where
# /dev/kfd is present. shell.sh does it; see the cache note there.
RUN set -eux; \
    git clone --filter=blob:none "$AITER_REPO" /opt/aiter-src; \
    cd /opt/aiter-src; \
    git fetch --no-tags origin "pull/${AITER_PR}/head"; \
    git checkout "$AITER_PR_COMMIT"; \
    git submodule update --init --recursive; \
    echo "aiter PR #${AITER_PR} @ ${AITER_PR_COMMIT}" > /opt/aiter-commit.txt; \
    grep -q "block_skip_threshold" aiter/ops/triton/attention/unified_attention.py \
      || { echo "pinned aiter commit has no block_skip_threshold"; exit 1; }

# --- ATOM's own runtime dependencies --------------------------------------
# Installed EXPLICITLY, by name. ATOM itself goes in with --no-deps (see
# shell.sh) so pip cannot resolve a dependency that replaces the ROCm torch or
# the patched Triton -- but --no-deps also means none of ATOM's own runtime
# requirements arrive, and the benchmark only needs torch/aiter/triton so the
# gap stays invisible until something larger runs. Starting the server in this
# image died at `ModuleNotFoundError: prometheus_client`.
#
# transformers and datasets are deliberately omitted: the base image already
# carries transformers, and both are torch-adjacent enough that letting pip
# resolve them risks pulling a different torch.
RUN set -eux; \
    pip install --no-cache-dir --break-system-packages \
        msgspec xxhash setproctitle uvloop pyzmq protobuf psutil tqdm \
        pybind11 openpyxl aiohttp fastapi uvicorn 'prometheus_client>=0.25,<0.26'; \
    python3 -c "import triton; assert triton.__version__.startswith('3.8'), \
                'the dependency install moved Triton off the patched build: ' + triton.__version__"

WORKDIR /workspace
