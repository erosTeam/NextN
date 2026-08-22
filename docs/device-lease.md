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
# checked project manifest. This entrypoint dry-runs before entering the lease.
scripts/run-device-protocol --device "$TARGET" --lease "$LEASE_ID" \
  docs/device-protocols/example.json

scripts/device-lease --device "$TARGET" release --lease "$LEASE_ID"
```

Direct lease-wrapped HDC is restricted to target discovery/reconnect,
`shell echo`, boot-completion readback, and artifact receive. Wake/timeout,
install/start, UI input, layout/screenshot, logs, traces, and other device-state
or evidence operations are rejected unless they are executed by the checked
manifest runner.

Use `renew` during a long-lived scenario. Do not use `--force` without an
explicit user instruction. The default shared lease root is
`~/.hermes/device-leases`; `HARMONY_DEVICE_LEASE_DIR` can override it, while
the existing `NEXTE_DEVICE_LEASE_DIR` is honored for cross-project continuity.
