# NextN device lease

`scripts/device-lease` is the advisory, explicit-target lock for agent-driven
device work. It coordinates agents; it never selects a device or expands user
authorization.

Resolve the user-selected target through live `hdc list targets -v`, then use
the full target for every lease operation. The helper has no default target.

```bash
TARGET=192.168.50.237:12345
LEASE_ID=$(scripts/device-lease --device "$TARGET" acquire \
  --owner "codex:nextn-reader-enhancement" \
  --project NextN \
  --ttl 30m \
  --reason "authorized Reader enhancement validation")

scripts/device-lease --device "$TARGET" run --lease "$LEASE_ID" -- \
  /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc \
  -t "$TARGET" shell echo ok

# After transport recovery, all stateful/evidentiary device work uses one
# checked project-owned manifest. A run-specific manifest belongs in an ignored
# artifact root; this entrypoint dry-runs before entering the lease.
scripts/run-device-protocol --device "$TARGET" --lease "$LEASE_ID" \
  .hvigor/outputs/<run>/input-manifest.json

scripts/device-lease --device "$TARGET" release --lease "$LEASE_ID"
```

## Manifest ownership and retention

The checked runner requires a project-owned manifest; it does not require every
manifest to be source controlled. Keep only stable, reusable scenario
definitions in Git. A manifest tied to one device run, artifact directory,
build hash, installation, wake, capture, retry, or cleanup step belongs under
an ignored project artifact root such as `.hvigor/outputs/` or
`.hermes-artifacts/` and must not be force-added. The runner copies the exact
input to the evidence directory as `protocol-manifest.json`, so each accepted
run remains auditable without adding another execution snapshot to
`docs/device-protocols/`.

Historical manifests remain recoverable from Git history. Current execution
evidence keeps its exact copied manifest beside `run-metadata.json`; do not add
run-specific JSON files to `docs/device-protocols/`.

One manifest must describe the complete uninterrupted scenario through its
preflight, measurement, and postflight phases. Do not split an ordinary route
into separate `gate`, `install`, `open`, `menu`, `capture`, `final`, or `exit`
manifests. A distinct manifest is justified only when an explicit decision
gate changes the next authorized action; it is still a local run input, not a
source file. `scripts/test_device_protocol_gate.py` and CI reject any JSON
manifest found or tracked under `docs/device-protocols/`.

Direct lease-wrapped HDC is restricted to target discovery/reconnect,
`shell echo`, boot-completion readback, and artifact receive. Wake/timeout,
install/start, UI input, layout/screenshot, logs, traces, and other device-state
or evidence operations are rejected unless they are executed by the checked
manifest runner.

Use `renew` during a long-lived scenario. Do not use `--force` without an
explicit user instruction. The default shared lease root is
`~/.hermes/device-leases`; `HARMONY_DEVICE_LEASE_DIR` can override it, while
the existing `NEXTE_DEVICE_LEASE_DIR` is honored for cross-project continuity.
