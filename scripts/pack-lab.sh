#!/usr/bin/env bash
# Stage lab deliverable under labs/<lab>/artifact/:
#   wave.svg, src/, build/ (no svg inside build).
# Optionally also write labs/<lab>/<lab>.zip for local use.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MAKE_ZIP=1
if [[ "${1:-}" == "--no-zip" ]]; then
  MAKE_ZIP=0
  shift
fi

if [[ $# -ge 1 && -n "${1:-}" ]]; then
  LAB="$1"
else
  LAB="$(tr -d '[:space:]' < .ci-lab)"
fi

LAB_DIR="labs/$LAB"
SRC_DIR="$LAB_DIR/src"
BUILD_DIR="$LAB_DIR/build"
WAVE_SVG="$LAB_DIR/wave.svg"
STAGE_DIR="$LAB_DIR/artifact"
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

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/src" "$STAGE_DIR/build"
cp -a "$WAVE_SVG" "$STAGE_DIR/wave.svg"
cp -a "$SRC_DIR"/. "$STAGE_DIR/src/"

shopt -s dotglob nullglob
for item in "$BUILD_DIR"/*; do
  base="$(basename "$item")"
  [[ "$base" == *.svg ]] && continue
  cp -a "$item" "$STAGE_DIR/build/"
done

echo "==> staged $STAGE_DIR"
find "$STAGE_DIR" -maxdepth 2 | sort

if [[ "$MAKE_ZIP" -eq 1 ]]; then
  rm -f "$OUT_ZIP"
  (
    cd "$STAGE_DIR"
    zip -r "$ROOT/$OUT_ZIP" wave.svg src build
  )
  echo "==> packed $OUT_ZIP (local only; CI uploads the folder)"
fi
