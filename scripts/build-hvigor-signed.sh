#!/usr/bin/env bash
set -euo pipefail

build_mode="${1:-debug}"
case "$build_mode" in
  debug)
    product="default"
    ;;
  release)
    product="release"
    ;;
  *)
    echo "Usage: $0 [debug|release]" >&2
    exit 64
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
public_profile="$project_root/build-profile.json5"

if [[ ! -f "$public_profile" ]] || ! grep -q '"signingConfigs"' "$public_profile"; then
  echo "ERROR: build-profile.json5 has no signingConfigs." >&2
  echo "Install the local signing profile with scripts/setup-local-build-profile.sh before signed builds." >&2
  exit 2
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  deveco_contents="${DEVECO_STUDIO_APP:-/Applications/DevEco-Studio.app}/Contents"
  deveco_jbr="$deveco_contents/jbr/Contents/Home"
  if [[ -d "$deveco_jbr" ]]; then
    export JAVA_HOME="${JAVA_HOME:-$deveco_jbr}"
    export PATH="$deveco_jbr/bin:$PATH"
  fi
  for directory in \
    "$deveco_contents/tools/ohpm/bin" \
    "$deveco_contents/tools/hvigor/bin" \
    "$deveco_contents/sdk/default/openharmony/toolchains"; do
    if [[ -d "$directory" ]]; then
      export PATH="$directory:$PATH"
    fi
  done
fi

if ! command -v hvigorw >/dev/null 2>&1; then
  echo "ERROR: hvigorw not found. Install DevEco command-line tools or set DEVECO_STUDIO_APP." >&2
  exit 127
fi

cd "$project_root"
hvigorw assembleHap --mode module -p product="$product" -p buildMode="$build_mode" --no-daemon
