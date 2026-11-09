#!/usr/bin/env python3
"""Fleet guardrail run in CI before anything is published.

Keeps the demo fleet inside what the platform team prepared: replicas within
the capacity budget, and an image that is one of the imported golden images.
"""
import subprocess
import sys

import yaml

ALLOWED_IMAGES = {"web-v1", "web-v2"}
MAX_REPLICAS = 5

docs = yaml.safe_load_all(subprocess.run(["kubectl", "kustomize", sys.argv[1]],
                                         check=True, capture_output=True, text=True).stdout)
errors = []
for d in docs:
    if not d or d.get("kind") != "SwiftGuestPool":
        continue
    name = d["metadata"]["name"]
    replicas = d["spec"]["replicas"]
    image = d["spec"]["template"]["spec"]["imageRef"]["name"]
    if not isinstance(replicas, int) or not 0 <= replicas <= MAX_REPLICAS:
        errors.append(f"{name}: replicas={replicas!r} outside 0..{MAX_REPLICAS}")
    if image not in ALLOWED_IMAGES:
        errors.append(f"{name}: imageRef {image!r} is not a prepared golden image {sorted(ALLOWED_IMAGES)}")
    print(f"{name}: replicas={replicas} image={image}")
if errors:
    sys.exit("policy violation:\n  " + "\n  ".join(errors))
print("policy OK")
