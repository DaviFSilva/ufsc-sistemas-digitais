#!/usr/bin/env bash
# Pack lab deliverable: wave.svg + src/ + build/ (no svg inside build).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -ge 1 && -n "${1:-}" ]]; then
  LAB="$1"
else
  LAB="$(tr -d '[:space:]' < .ci-lab)"
fi

LAB_DIR="labs/$LAB"
SRC_DIR="$LAB_DIR/src"
BUILD_DIR="$LAB_DIR/build"
WAVE_SVG="$LAB_DIR/wave.svg"
OUT_ZIP="$LAB_DIR/${LAB}.zip"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "error: missing $SRC_DIR" >&2
  exit 1
fi
if [[ ! -d "$BUILD_DIR" ]]; then
  echo "error: missing $BUILD_DIR (run build first)" >&2
  exit 1
fi
if [[ ! -f "$WAVE_SVG" ]]; then
  echo "error: missing $WAVE_SVG (run build first)" >&2
  exit 1
fi

# Ensure svg is not left inside build/
rm -f "$BUILD_DIR/wave.svg"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/src" "$STAGE/build"
cp -a "$WAVE_SVG" "$STAGE/wave.svg"
cp -a "$SRC_DIR"/. "$STAGE/src/"
# copy build but drop any svg just in case
shopt -s dotglob nullglob
for item in "$BUILD_DIR"/*; do
  base="$(basename "$item")"
  [[ "$base" == *.svg ]] && continue
  cp -a "$item" "$STAGE/build/"
done

rm -f "$OUT_ZIP"
(
  cd "$STAGE"
  zip -r "$ROOT/$OUT_ZIP" wave.svg src build
)

echo "==> packed $OUT_ZIP"
unzip -l "$OUT_ZIP" | head -40
