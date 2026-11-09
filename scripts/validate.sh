#!/usr/bin/env bash
# Validate Kustomize overlays against the real CRD schemas of the versions this
# demo runs (strict: unknown fields fail, which is how a typo such as
# `classRef` for `guestClassRef` is caught before it is ever published).
#   usage: scripts/validate.sh <kustomize-dir>...
# Runs in CI (.github/workflows/push-artifact.yaml); needs helm, kubectl, python3-yaml.
set -euo pipefail
KUBESWIFT_CHART=0.23.0
FLUX=v2.10.0
FLUX_OPERATOR=v0.62.1
KUBECONFORM=v0.8.0
K8S=1.34.0

here="$(cd "$(dirname "$0")" && pwd)"
work="${VALIDATE_CACHE:-$(mktemp -d)}"
mkdir -p "$work/schemas" "$work/bin"

if [ ! -x "$work/bin/kubeconform" ]; then
  curl -fsSL "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM}/kubeconform-linux-amd64.tar.gz" | tar -xz -C "$work/bin" kubeconform
fi
if [ ! -f "$work/schemas/.done" ]; then
  helm pull oci://ghcr.io/kubeswift-io/charts/kubeswift --version "$KUBESWIFT_CHART" --untar -d "$work/chart" >/dev/null
  curl -fsSL -o "$work/flux.yaml" "https://github.com/fluxcd/flux2/releases/download/${FLUX}/install.yaml"
  curl -fsSL -o "$work/flux-operator.yaml" "https://github.com/controlplaneio-fluxcd/flux-operator/releases/download/${FLUX_OPERATOR}/install.yaml"
  (cd "$work/schemas" && python3 "$here/openapi2jsonschema.py" "$work"/chart/kubeswift/crds/*.yaml "$work/flux.yaml" "$work/flux-operator.yaml" >/dev/null)
  touch "$work/schemas/.done"
fi

rc=0
for dir in "$@"; do
  echo "--- $dir"
  kubectl kustomize "$dir" > "$work/out.yaml"
  "$work/bin/kubeconform" -strict -summary -kubernetes-version "$K8S" \
    -schema-location default \
    -schema-location "$work/schemas/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json" \
    "$work/out.yaml" || rc=1
done
exit $rc
