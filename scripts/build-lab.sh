#!/usr/bin/env bash
set -euo pipefail

# GHDL's GCC backend shells out to `as`. Cross-toolchains (e.g. arm-none-eabi)
# often shadow the host assembler and produce dozens of fake asm errors.
export PATH="/usr/bin:/bin:${PATH}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -ge 1 && -n "${1:-}" ]]; then
  LAB="$1"
else
  if [[ ! -f .ci-lab ]]; then
    echo "error: .ci-lab not found and no lab name given" >&2
    exit 1
  fi
  LAB="$(tr -d '[:space:]' < .ci-lab)"
fi

if [[ -z "$LAB" ]]; then
  echo "error: lab name is empty" >&2
  exit 1
fi

LAB_DIR="labs/$LAB"
SRC_DIR="$LAB_DIR/src"
MANIFEST="$LAB_DIR/lab.yml"

if [[ ! -d "$LAB_DIR" ]]; then
  echo "error: lab directory not found: $LAB_DIR" >&2
  exit 1
fi

if [[ ! -d "$SRC_DIR" ]]; then
  echo "error: source directory not found: $SRC_DIR" >&2
  exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "error: manifest not found: $MANIFEST" >&2
  exit 1
fi

if ! command -v ghdl >/dev/null 2>&1; then
  echo "error: ghdl not found in PATH" >&2
  exit 1
fi

mapfile -t SOURCES < <(python3 - "$MANIFEST" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
sources = []
in_sources = False
testbench = None

for raw in path.read_text().splitlines():
    line = raw.split("#", 1)[0].rstrip()
    if not line.strip():
        continue
    if line.startswith("sources:"):
        in_sources = True
        continue
    if line.startswith("testbench:"):
        in_sources = False
        testbench = line.split(":", 1)[1].strip()
        continue
    if in_sources and line.lstrip().startswith("-"):
        sources.append(line.split("-", 1)[1].strip())

if not sources:
    sys.exit("error: no sources listed in lab.yml")
if not testbench:
    sys.exit("error: testbench missing in lab.yml")

for src in sources:
    print(src)
print(f"__TESTBENCH__={testbench}")
PY
)

TESTBENCH=""
SRC_FILES=()
for item in "${SOURCES[@]}"; do
  if [[ "$item" == __TESTBENCH__=* ]]; then
    TESTBENCH="${item#__TESTBENCH__=}"
  else
    SRC_FILES+=("$item")
  fi
done

if [[ ${#SRC_FILES[@]} -eq 0 || -z "$TESTBENCH" ]]; then
  echo "error: failed to parse $MANIFEST" >&2
  exit 1
fi

WORK_DIR="$LAB_DIR/build"
WAVE_SVG="$LAB_DIR/wave.svg"
rm -rf "$WORK_DIR"
rm -f "$WAVE_SVG"
mkdir -p "$WORK_DIR"

echo "==> Building lab: $LAB"
echo "==> Testbench: $TESTBENCH"

ABS_SOURCES=()
for src in "${SRC_FILES[@]}"; do
  if [[ ! -f "$SRC_DIR/$src" ]]; then
    echo "error: source not found: $SRC_DIR/$src" >&2
    exit 1
  fi
  ABS_SOURCES+=("../src/$src")
done

(
  cd "$WORK_DIR"
  echo "==> ghdl -a"
  for src in "${ABS_SOURCES[@]}"; do
    echo "    analyzing $src"
    ghdl -a --std=08 "$src"
  done

  echo "==> ghdl -e $TESTBENCH"
  ghdl -e --std=08 "$TESTBENCH"

  echo "==> ghdl -r $TESTBENCH (GHW -> wave.ghw)"
  ghdl -r --std=08 "$TESTBENCH" --assert-level=error --stop-time=1ms --wave=wave.ghw
)

if [[ -f "$WORK_DIR/wave.ghw" ]]; then
  echo "==> plotting $WAVE_SVG"
  python3 "$ROOT/scripts/ghw-to-svg.py" "$WORK_DIR/wave.ghw" \
    -o "$WAVE_SVG" \
    --title "$LAB"
fi

echo "==> OK: $LAB"
echo "    GHW: $WORK_DIR/wave.ghw"
echo "    SVG: $WAVE_SVG"
