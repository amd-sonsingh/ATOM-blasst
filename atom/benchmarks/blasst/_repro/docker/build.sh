#!/bin/bash
# Build the reproduction image: patched Triton + pinned aiter. ~15 min.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a; . "$HERE/../pins.env"; set +a

# Stage a minimal context. A context rooted at the ATOM checkout would hand the
# daemon the whole tree for a Dockerfile that needs exactly one patch file.
CTX="$(mktemp -d)"; trap 'rm -rf "$CTX"' EXIT
cp "$HERE/Dockerfile" "$CTX/"
cp "$HERE/../patch/0001-force-chain-dot-across-scf-if.patch" "$CTX/"

echo "image : $IMAGE"
echo "triton: $TRITON_COMMIT (patched)"
echo "aiter : PR #$AITER_PR @ $AITER_PR_COMMIT"
docker build --network=host -t "$IMAGE" \
  --build-arg TRITON_REPO="$TRITON_REPO" \
  --build-arg TRITON_COMMIT="$TRITON_COMMIT" \
  --build-arg AITER_REPO="$AITER_REPO" \
  --build-arg AITER_PR="$AITER_PR" \
  --build-arg AITER_PR_COMMIT="$AITER_PR_COMMIT" \
  "$CTX"
echo; echo "built $IMAGE -- next: bash _repro/shell.sh"
