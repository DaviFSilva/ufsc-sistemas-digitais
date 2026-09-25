#!/usr/bin/env bash
set -euo pipefail

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
MANIFEST="$LAB_DIR/lab.yml"

if [[ ! -d "$LAB_DIR" ]]; then
  echo "error: lab directory not found: $LAB_DIR" >&2
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
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "==> Building lab: $LAB"
echo "==> Testbench: $TESTBENCH"

ABS_SOURCES=()
for src in "${SRC_FILES[@]}"; do
  if [[ ! -f "$LAB_DIR/$src" ]]; then
    echo "error: source not found: $LAB_DIR/$src" >&2
    exit 1
  fi
  ABS_SOURCES+=("../$src")
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

  echo "==> ghdl -r $TESTBENCH"
  ghdl -r --std=08 "$TESTBENCH" --assert-level=error --stop-time=1ms
)

echo "==> OK: $LAB"
