#!/usr/bin/env python3
"""Convert a GHDL .ghw wave dump to a digital timing SVG via ghwdump.

Preserves VHDL types from GHW: enums (e.g. state_t) are shown by name,
std_logic_vector values as VHDL bit-string literals ("01").
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class SignalDef:
    name: str  # display name (leaf)
    path: str  # full /a/b/c path
    ids: list[int]  # MSB..LSB for downto vectors
    kind: str  # "bit" | "bus" | "enum"
    depth: int


@dataclass
class Signal:
    name: str
    kind: str  # "bit" | "bus" | "enum"
    values: list[tuple[int, str]] = field(default_factory=list)


_HIER_RE = re.compile(
    r"^(?:signal|port-\w+)\s+(/[^:]+):\s+(.+?):\s+#(\d+)(?:-#(\d+))?\s*$"
)
_VEC_RE = re.compile(
    r"(std_u?logic_vector)\s*\(\s*(\d+)\s+(downto|to)\s+(\d+)\s*\)",
    re.I,
)
_TIME_RE = re.compile(r"^Time is (\d+)\s+")
_VAL_RE = re.compile(r"^#(\d+):\s+(.+?)\s+\(\d+\)\s*$")

DEFAULT_SIGNALS = [
    "clk",
    "rst_a",
    "ok",
    "play",
    "winner",
    "currentstate",
    "nextstate",
]


def _run_ghwdump(args: list[str], ghw: Path) -> str:
    ghwdump = shutil.which("ghwdump")
    if not ghwdump:
        raise SystemExit("error: ghwdump not found (install GHDL)")
    proc = subprocess.run(
        [ghwdump, *args, str(ghw)],
        check=True,
        capture_output=True,
        text=True,
    )
    return proc.stdout


def _is_std_logic_type(typ: str) -> bool:
    t = typ.lower().strip()
    return t in ("std_logic", "std_ulogic") or t.startswith("std_logic ") or t.startswith("std_ulogic ")


def parse_hierarchy(ghw: Path) -> dict[str, SignalDef]:
    """Map leaf name -> best SignalDef (prefer shallower hierarchy)."""
    text = _run_ghwdump(["-H"], ghw)
    found: dict[str, SignalDef] = {}

    for line in text.splitlines():
        m = _HIER_RE.match(line.strip())
        if not m:
            continue
        path, typ, id0_s, id1_s = m.group(1), m.group(2), m.group(3), m.group(4)
        parts = [p for p in path.split("/") if p]
        if len(parts) < 2:
            continue
        leaf = parts[-1]
        depth = len(parts)
        id0 = int(id0_s)

        vm = _VEC_RE.search(typ)
        if vm:
            left, direction, right = int(vm.group(2)), vm.group(3).lower(), int(vm.group(4))
            id1 = int(id1_s) if id1_s else id0
            # ghwdump lists #lo-#hi in storage order matching the index declaration
            ids = list(range(id0, id1 + 1))
            if direction == "downto" and left < right:
                ids = list(reversed(ids))
            # For "1 downto 0", id0 is index 1 (MSB), id1 is index 0 (LSB) — already MSB..LSB
            kind = "bus"
        elif id1_s:
            ids = list(range(id0, int(id1_s) + 1))
            kind = "bus"
        elif _is_std_logic_type(typ):
            ids = [id0]
            kind = "bit"
        else:
            # VHDL enum / other scalar typed signal (e.g. state_t)
            ids = [id0]
            kind = "enum"

        cand = SignalDef(name=leaf, path=path, ids=ids, kind=kind, depth=depth)
        prev = found.get(leaf)
        # Prefer TB-level (shallower) when the same leaf exists on ports and internals
        if prev is None or cand.depth < prev.depth:
            found[leaf] = cand

    return found


def _normalize_bit(raw: str) -> str:
    raw = raw.strip().strip("'").lower()
    if raw == "1":
        return "1"
    if raw == "0":
        return "0"
    return "x"


def _format_enum(raw: str) -> str:
    # ghwdump: wait_p1 (0)  → WAIT_P1
    name = raw.strip().strip("'").split()[0]
    return name.upper()


def _format_bus(bits: list[str]) -> str:
    if any(b == "x" for b in bits):
        return '"XX"'
    return '"' + "".join(bits) + '"'


def parse_samples(ghw: Path, defs: dict[str, SignalDef]) -> list[Signal]:
    text = _run_ghwdump(["-s"], ghw)
    id_values: dict[int, str] = {}
    series: dict[str, list[tuple[int, str]]] = {n: [] for n in defs}
    last: dict[str, str] = {}
    prev_time: int | None = None

    def snapshot(t: int) -> None:
        for name, d in defs.items():
            if d.kind == "bus":
                bits = [_normalize_bit(id_values.get(i, "x")) for i in d.ids]
                val = _format_bus(bits)
            elif d.kind == "bit":
                val = _normalize_bit(id_values.get(d.ids[0], "x"))
            else:
                raw = id_values.get(d.ids[0], "x")
                val = _format_enum(raw) if raw != "x" else "X"
            if last.get(name) != val:
                series[name].append((t, val))
                last[name] = val

    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        tm = _TIME_RE.match(line)
        if tm:
            if prev_time is not None:
                snapshot(prev_time)
            prev_time = int(tm.group(1))
            continue
        vm = _VAL_RE.match(line)
        if vm:
            id_values[int(vm.group(1))] = vm.group(2).strip()

    if prev_time is not None:
        snapshot(prev_time)

    signals: list[Signal] = []
    for name, d in defs.items():
        sig = Signal(name=name, kind=d.kind, values=series[name])
        if not sig.values:
            sig.values = [(0, "X" if d.kind != "bit" else "x")]
        signals.append(sig)
    return signals


def render_svg(
    signals: list[Signal],
    out: Path,
    names: list[str] | None = None,
    title: str = "waveform",
) -> None:
    if names:
        wanted = {n.lower() for n in names}
        by_leaf = {s.name.lower(): s for s in signals}
        ordered: list[Signal] = []
        for n in names:
            s = by_leaf.get(n.lower())
            if s is not None:
                ordered.append(s)
        for s in signals:
            if s.name.lower() in wanted and s not in ordered:
                ordered.append(s)
        signals = ordered

    if not signals:
        raise SystemExit("error: no signals to plot")

    tmax = max((t for s in signals for t, _ in s.values), default=1) or 1

    label_w = max(110, max(len(s.name) for s in signals) * 8 + 16)
    left = label_w
    top = 40
    row_h = 44
    wave_h = 26
    right_pad = 40

    # Size the canvas so bus/enum segments stay readable (VHDL names fit).
    min_seg_px = 70
    typed_durs: list[int] = []
    for sig in signals:
        if sig.kind == "bit":
            continue
        times = [t for t, _ in sorted(sig.values)]
        if times and times[0] > 0:
            times = [0] + times
        times = times + [tmax]
        for a, b in zip(times, times[1:]):
            if b > a:
                typed_durs.append(b - a)
    scale = (1200 - left - right_pad) / tmax
    if typed_durs:
        scale = max(scale, min_seg_px / min(typed_durs))
    width_px = int(left + tmax * scale + right_pad)
    # Cap extreme width but keep a high ceiling for lab dumps
    width_px = min(max(width_px, 1200), 8000)
    scale = (width_px - left - right_pad) / tmax
    height = top + row_h * len(signals) + 40

    def x_of(t: int) -> float:
        return left + t * scale

    def esc(s: str) -> str:
        return (
            s.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
        )

    enum_fill = "#1a2332"
    enum_stroke = "#58a6ff"  # blue for VHDL enum states
    bus_fill = "#1c1229"
    bus_stroke = "#d2a8ff"  # pink for std_logic_vector buses
    bit_stroke = "#3fb950"

    parts: list[str] = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width_px}" height="{height}" '
        f'font-family="ui-monospace, Menlo, monospace" font-size="12">',
        '<rect width="100%" height="100%" fill="#0f1419"/>',
        f'<text x="16" y="24" fill="#e6edf3" font-size="14">{esc(title)}</text>',
    ]

    step = max(1, tmax // 10)
    for t in range(0, tmax + 1, step):
        x = x_of(t)
        parts.append(
            f'<line x1="{x:.1f}" y1="{top - 8}" x2="{x:.1f}" y2="{height - 20}" '
            f'stroke="#21262d" stroke-width="1"/>'
        )
        label = f"{t // 1_000_000}ns" if t >= 1_000_000 else str(t)
        parts.append(
            f'<text x="{x:.1f}" y="{height - 6}" fill="#8b949e" text-anchor="middle">{label}</text>'
        )

    def gtkwave_bus_path(x0: float, x1: float, y_hi: float, y_lo: float, y_mid: float) -> str:
        """Hexagon / bow-tie segment like GTKWave multi-bit traces."""
        w = x1 - x0
        # Tip depth: up to half the segment, capped for readability
        tip = min(8.0, max(2.0, w * 0.35))
        if w < tip * 2 + 1:
            # Too narrow for a full hexagon — draw a thin diamond
            tip = w / 2
            return (
                f"M {x0:.1f} {y_mid:.1f} "
                f"L {x0 + tip:.1f} {y_hi:.1f} "
                f"L {x1:.1f} {y_mid:.1f} "
                f"L {x0 + tip:.1f} {y_lo:.1f} Z"
            )
        return (
            f"M {x0:.1f} {y_mid:.1f} "
            f"L {x0 + tip:.1f} {y_hi:.1f} "
            f"L {x1 - tip:.1f} {y_hi:.1f} "
            f"L {x1:.1f} {y_mid:.1f} "
            f"L {x1 - tip:.1f} {y_lo:.1f} "
            f"L {x0 + tip:.1f} {y_lo:.1f} Z"
        )

    for i, sig in enumerate(signals):
        y0 = top + i * row_h
        y_lo = y0 + wave_h
        y_hi = y0
        y_mid = y0 + wave_h / 2
        parts.append(
            f'<text x="12" y="{y0 + wave_h * 0.72:.1f}" fill="#e6edf3">{esc(sig.name)}</text>'
        )

        changes = sorted(sig.values, key=lambda p: p[0])
        if changes[0][0] > 0:
            changes = [(0, changes[0][1])] + changes
        samples = changes + [(tmax, changes[-1][1])]

        if sig.kind == "bit":
            path = []
            for j in range(len(samples) - 1):
                t0, v0 = samples[j]
                t1, _ = samples[j + 1]
                y = y_hi if v0 == "1" else y_lo if v0 == "0" else y_mid
                x0, x1 = x_of(t0), x_of(t1)
                if j == 0:
                    path.append(f"M {x0:.1f} {y:.1f}")
                else:
                    path.append(f"L {x0:.1f} {y:.1f}")
                path.append(f"L {x1:.1f} {y:.1f}")
            parts.append(
                f'<path d="{" ".join(path)}" fill="none" stroke="{bit_stroke}" stroke-width="1.5"/>'
            )
            continue

        # Buses and enums: GTKWave hexagon style, pink stroke
        fill = bus_fill if sig.kind == "bus" else enum_fill
        stroke = bus_stroke if sig.kind == "bus" else enum_stroke
        for j in range(len(samples) - 1):
            t0, v0 = samples[j]
            t1, _ = samples[j + 1]
            if t1 <= t0:
                continue
            x0, x1 = x_of(t0), x_of(t1)
            w = max(x1 - x0, 1)
            d = gtkwave_bus_path(x0, x1, y_hi, y_lo, y_mid)
            parts.append("<g>")
            parts.append(
                f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="1.4" '
                f'stroke-linejoin="round"/>'
            )
            parts.append(f"<title>{esc(v0)}</title>")
            max_chars = max(2, int((w - 12) / 7.5))
            label = v0 if len(v0) <= max_chars else v0[: max(1, max_chars - 1)] + "…"
            if w >= 24:
                parts.append(
                    f'<text x="{(x0 + x1) / 2:.1f}" y="{y_mid + 4:.1f}" fill="#e6edf3" '
                    f'text-anchor="middle" font-size="10">{esc(label)}</text>'
                )
            parts.append("</g>")

    parts.append("</svg>")
    out.write_text("\n".join(parts) + "\n")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("ghw", type=Path)
    ap.add_argument("-o", "--output", type=Path, required=True)
    ap.add_argument("-s", "--signals", nargs="*", default=None)
    ap.add_argument("--title", default="waveform")
    args = ap.parse_args()

    if not args.ghw.is_file():
        print(f"error: GHW not found: {args.ghw}", file=sys.stderr)
        sys.exit(1)

    defs = parse_hierarchy(args.ghw)
    if not defs:
        print("error: no signals found in GHW hierarchy", file=sys.stderr)
        sys.exit(1)

    signals = parse_samples(args.ghw, defs)
    names = args.signals
    if not names:
        have = {s.name.lower() for s in signals}
        names = [n for n in DEFAULT_SIGNALS if n.lower() in have]
        if not names:
            names = [s.name for s in signals[:12]]

    render_svg(signals, args.output, names=names, title=args.title)
    print(f"wrote {args.output}")


if __name__ == "__main__":
    main()
