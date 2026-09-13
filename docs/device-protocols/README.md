# Device protocols

This directory contains stable, human-reviewed device policies and route
contracts only. It must not contain JSON execution manifests.

Create run-specific manifests under a project-owned ignored artifact root such
as `.hvigor/outputs/<run>/input-manifest.json` or
`.hermes-artifacts/<run>/input-manifest.json`. A single manifest owns the full
preflight, measurement, and postflight chain. The checked runner retains the
exact input beside the run evidence as `protocol-manifest.json`.

Historical JSON manifests removed on 2026-09-14 remain recoverable from Git
history. Do not restore or force-add them.
