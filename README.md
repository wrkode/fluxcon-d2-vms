# fluxcon-d2-vms

Application-team repository for the FluxCon 2026 demo *"Your VMs Are Just
CRDs"*: the D2 **apps** analogue. It holds one thing, the web VM fleet, as a
KubeSwift `SwiftGuestPool`.

Every merge to `main` runs `.github/workflows/push-artifact.yaml`:

1. validate `web-fleet/` against the KubeSwift/Flux CRD schemas, plus a fleet policy
2. `flux push artifact` to `ghcr.io/wrkode/fluxcon-d2-vms/web-fleet:main-<sha12>`
3. keyless `cosign sign` (GitHub OIDC), then `cosign verify` against this workflow's identity
4. move the `latest` tag to that digest

In the cluster, a Flux `OCIRepository` verifies the signature
(`spec.verify.provider: cosign`, `matchOIDCIdentity` pinned to this workflow on
`refs/heads/main`), and the `kubeswift-workloads` Kustomization applies it.
KubeSwift turns the pool into VMs. No cluster ever reads this Git repository.

| Field | Owner |
|---|---|
| `spec.replicas` | this repo (no autoscaler; a manual `kubectl scale` is drift and Flux reverts it) |
| `spec.template.spec.imageRef` | this repo, limited to the golden images prepared in fluxcon-d2-infra |
| guest class, images, seed | [fluxcon-d2-infra](https://github.com/wrkode/fluxcon-d2-infra) |
| sources, reconcilers, verification policy | [fluxcon-d2-fleet](https://github.com/wrkode/fluxcon-d2-fleet) |

Based on the Flux D2 reference architecture by ControlPlane
([d2-apps](https://github.com/controlplaneio-fluxcd/d2-apps), Apache-2.0),
reduced to a single cluster.
