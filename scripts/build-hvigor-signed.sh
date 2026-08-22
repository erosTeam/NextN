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
safe_flag_file="$project_root/shared/src/main/ets/safe/SafeModeBuildFlag.ets"
safe_flag_backup=""

restore_safe_flag() {
  if [[ -n "$safe_flag_backup" && -f "$safe_flag_backup" ]]; then
    cp "$safe_flag_backup" "$safe_flag_file"
    rm -f "$safe_flag_backup"
  fi
}

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

if [[ "${NEXTN_SAFE_MODE:-0}" == "1" ]]; then
  safe_flag_backup="$(mktemp)"
  cp "$safe_flag_file" "$safe_flag_backup"
  trap restore_safe_flag EXIT
  python3 - "$safe_flag_file" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
next_text = re.sub(
    r'SAFE_MODE_BUILD_ENABLED: boolean = false',
    'SAFE_MODE_BUILD_ENABLED: boolean = true',
    text,
    count=1,
)
if next_text == text:
    raise SystemExit('ERROR: safe mode build flag pattern not found')
path.write_text(next_text, encoding='utf-8')
PY
fi

cd "$project_root"
hvigorw assembleHap --mode module -p product="$product" -p buildMode="$build_mode" --no-daemon
