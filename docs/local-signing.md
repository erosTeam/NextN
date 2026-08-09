# Local signing

`build-profile.local.json5` is intentionally ignored. It contains the local signing material for NextN's debug and release products and is copied into the active build profile only for the duration of a signed build.

Run either command from the project root:

```sh
bash scripts/build-hvigor-signed.sh debug
bash scripts/build-hvigor-signed.sh release
```

The public `build-profile.json5` remains free of local signing material after each command, including on build failure.

Use the Debug product for HDC/device development validation. A Release profile is a distribution trust boundary: a locally signed Release HAP can build successfully yet be rejected by a development device's direct-install path. Validate that package through its intended release/distribution trust channel after confirming the Release profile and certificate association.
