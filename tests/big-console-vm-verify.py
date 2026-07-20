# SPDX-License-Identifier: GPL-3.0-or-later
# Verifier for the big-console-vm check.
#
# Modes:
#   --bright DUMP.ppm          exit 0 iff the dump has enough lit pixels to be
#                              a rendered console screen (poll-loop filter)
#   AFTER.txt DUMP.ppm CELLW CELLH SCALE
#                              full assertions (see big-console-vm.nix header)
import re
import sys

import numpy as np

BRIGHT = 0x60
MIN_BRIGHT_PIXELS = 500


def load_ppm(path):
    data = open(path, "rb").read()
    m = re.match(rb"P6\s+(\d+)\s+(\d+)\s+(\d+)\s", data)
    assert m, f"{path}: not a raw PPM"
    w, h, maxval = map(int, m.groups())
    assert maxval == 255, f"{path}: unexpected maxval {maxval}"
    px = np.frombuffer(data, dtype=np.uint8, count=w * h * 3, offset=m.end())
    return px.reshape(h, w, 3)


def bright_mask(img):
    return (img > BRIGHT).any(axis=2)


def min_horizontal_run(mask):
    # Shortest horizontal run of lit pixels across all rows: pad each row
    # with dark, diff the transitions, and collect run lengths.
    padded = np.zeros((mask.shape[0], mask.shape[1] + 2), dtype=np.int8)
    padded[:, 1:-1] = mask
    d = np.diff(padded, axis=1)
    starts = np.argwhere(d == 1)
    ends = np.argwhere(d == -1)
    assert len(starts) == len(ends)
    runs = ends[:, 1] - starts[:, 1]
    return int(runs.min()) if len(runs) else None


def parse_mode_table(path):
    raw = open(path, "rb").read()
    text = raw.decode("utf-16") if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else raw.decode(
        "utf-8", "replace"
    )
    modes = [(int(c), int(r)) for c, r in re.findall(r"Col\s+(\d+)\s+Row\s+(\d+)", text)]
    assert modes, f"no text modes parsed from {path}: {text!r}"
    return modes


def main():
    if sys.argv[1] == "--bright":
        try:
            img = load_ppm(sys.argv[2])
        except Exception as exc:
            print(f"dump: unreadable ({exc})", file=sys.stderr)
            sys.exit(1)
        lit = int(bright_mask(img).sum())
        print(f"dump: {img.shape[1]}x{img.shape[0]}, lit={lit}", file=sys.stderr)
        sys.exit(0 if lit >= MIN_BRIGHT_PIXELS else 1)

    after_path, ppm_path = sys.argv[1], sys.argv[2]
    cell_w, cell_h, scale = (int(a) for a in sys.argv[3:6])

    img = load_ppm(ppm_path)
    h, w = img.shape[:2]
    modes = parse_mode_table(after_path)
    max_cols = max(c for c, _ in modes)
    max_rows = max(r for _, r in modes)

    print(f"framebuffer: {w}x{h}")
    print(f"modes after takeover: {modes}")

    assert w >= 3840, f"framebuffer not 4K-class: {w}x{h}"

    expect_cols = w // cell_w
    expect_rows = h // cell_h
    assert max_cols == expect_cols, f"max columns {max_cols} != {expect_cols} (w={w}, cell_w={cell_w})"
    assert max_rows == expect_rows, f"max rows {max_rows} != {expect_rows} (h={h}, cell_h={cell_h})"

    mask = bright_mask(img)
    lit = int(mask.sum())
    print(f"lit pixels: {lit}")
    assert lit >= MIN_BRIGHT_PIXELS, "screen effectively empty"

    # Text lines must actually use the tall cells: the tallest contiguous
    # band of lit rows (a rendered text line) has to fill most of a cell.
    # An unscaled 8x19 rendering inside big cells never gets close.
    lit_rows = mask.any(axis=1).astype(np.int8)
    padded = np.concatenate(([0], lit_rows, [0]))
    d = np.diff(padded)
    bands = np.flatnonzero(d == -1) - np.flatnonzero(d == 1)
    band = int(bands.max()) if len(bands) else 0
    print(f"tallest lit-row band: {band} (cell height {cell_h})")
    assert band * 100 >= cell_h * 55, f"text band {band}px too short for {cell_h}px cells"

    # With integer magnification no foreground stem can be thinner than the
    # scale factor (the base font may legitimately have 1px stems).
    if scale >= 2:
        run = min_horizontal_run(mask)
        print(f"min horizontal run: {run}")
        assert run is not None and run >= scale, (
            f"found a {run}px foreground run < scale {scale}: text is not pixel-magnified"
        )

    print("ok: scaled mode table and cell-filling rendering verified")


if __name__ == "__main__":
    main()
