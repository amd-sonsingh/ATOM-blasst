"""End-to-end check that BLASST survives a long-context request.

Sends one ~30K-token prompt with a checkable fact buried in the middle, at the
range the reference threshold was calibrated for (943/seqlen gives ~0.03 at
32K). A short prompt proves nothing: the same fit yields a threshold above 1.0
under ~1000 tokens, far outside where it was measured.

This does NOT prove skipping engaged -- the server reports no elision counter.
For that, run the same prompt against a server started without the three
ATOM_BLASST_* variables and compare prefill time and output. Start that server
with --no-enable_prefix_caching, or the second run is served from the first
run's KV cache and the comparison is meaningless.

    python3 atom/benchmarks/blasst/_repro/server_probe.py
"""

import json, time, urllib.request

BASE = "http://localhost:8000"

def post(path, payload, timeout=900):
    req = urllib.request.Request(BASE + path, json.dumps(payload).encode(),
                                 {"Content-Type": "application/json"})
    t0 = time.time()
    out = json.load(urllib.request.urlopen(req, timeout=timeout))
    return out, time.time() - t0

# Read the served id rather than assuming it -- it is whatever --model was given.
models = json.load(urllib.request.urlopen(BASE + "/v1/models", timeout=30))
model = models["data"][0]["id"]
print("model:", model)

# ~30K tokens of filler with a checkable fact buried in the middle. Long enough
# to be in the range the threshold was calibrated for (943/seqlen -> ~0.03).
filler = "The quick brown fox jumps over the lazy dog. " * 3000
half = len(filler) // 2
prompt = (filler[:half]
          + "\nThe secret passcode is 4815162342.\n"
          + filler[half:]
          + "\n\nQuestion: what is the secret passcode? Answer with the number only.\nAnswer:")

out, secs = post("/v1/completions",
                 {"model": model, "prompt": prompt, "max_tokens": 32, "temperature": 0})
text = out["choices"][0]["text"].strip()
usage = out.get("usage", {})
print(f"prompt tokens : {usage.get('prompt_tokens')}")
print(f"wall time     : {secs:.1f}s")
print(f"answer        : {text[:120]!r}")
print(f"needle found  : {'4815162342' in text}")
