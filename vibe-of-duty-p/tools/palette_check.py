"""Palette metric for screenshots, against the owner's taste (Docs/AUTHOR.md, "Визуал"): how much of the frame is
black, how grey the rest is, and how much of it is accent.

Run:  python vibe-of-duty-p/tools/palette_check.py shots/level_*.png
Per image: black share (value < 0.06), accent share (chroma > ACCENT_CHROMA), mean chroma of the non-accent rest and
the mean colour of the accent. Chroma is max - min of the RGB channels (0..1): unlike HSV saturation it doesn't blow
up on near-black pixels. Targets: rest chroma < ~0.05, accent <= 3-5% of the frame.
"""
import sys

from PIL import Image

BLACK_VALUE = 0.06
ACCENT_CHROMA = 0.15
SIZE = 320  # images are scaled down first: the metric is about areas, not detail


def check(path):
    image = Image.open(path).convert("RGB")
    image.thumbnail((SIZE, SIZE))
    data = image.tobytes()
    pixels = [tuple(data[i:i + 3]) for i in range(0, len(data), 3)]
    black = accent = 0
    rest_chroma = 0.0
    accent_sum = [0, 0, 0]
    for r, g, b in pixels:
        hi, lo = max(r, g, b) / 255.0, min(r, g, b) / 255.0
        if hi < BLACK_VALUE:
            black += 1
        chroma = hi - lo
        if chroma > ACCENT_CHROMA:
            accent += 1
            accent_sum[0] += r
            accent_sum[1] += g
            accent_sum[2] += b
        else:
            rest_chroma += chroma
    n = len(pixels)
    accent_hex = "#%02x%02x%02x" % tuple(c // accent for c in accent_sum) if accent else "-"
    print("%-40s black %4.1f%%  accent %4.1f%% %s  rest chroma %.3f" % (
        path, 100.0 * black / n, 100.0 * accent / n, accent_hex, rest_chroma / max(1, n - accent)))


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        check(arg)
