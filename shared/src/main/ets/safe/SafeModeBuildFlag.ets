// Normal builds are unrestricted. The signed-build entrypoint temporarily
// flips this constant for a dedicated restricted build and restores it on exit.
export const SAFE_MODE_BUILD_ENABLED: boolean = false
