"""Image-quality metrics for tests/quality_probe.gd captures.

contrast_far : RMS contrast (std of luminance, 0-255) in the distant region; low = washed out
mean_far     : mean luminance there; high together with low contrast = haze/veil
grain        : mean |Laplacian| of a still in the mid/far region (fine high-frequency energy)
shimmer      : mean high-frequency residual between consecutive pan frames after aligning the
               integer horizontal shift - aliasing/crawling that a still cannot show
Usage: python -I quality_metrics.py <probe_dir> <map_id>
"""
import glob, os, sys
import numpy as np
from PIL import Image

# regions (x0, y0, x1, y1) at 1280x720: far = end of the view, mid = surfaces 10-30 m away
REGIONS = {
    0: {"far": (480, 200, 800, 380), "mid": (200, 120, 1080, 400)},
    1: {"far": (500, 220, 780, 400), "mid": (250, 150, 1030, 420)},
    2: {"far": (300, 250, 980, 380), "mid": (200, 240, 1080, 420)},
}


def lum(path, box):
    a = np.asarray(Image.open(path).convert("RGB").crop(box), dtype=np.float32)
    return a @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def lap(a):
    return np.abs(4 * a[1:-1, 1:-1] - a[:-2, 1:-1] - a[2:, 1:-1] - a[1:-1, :-2] - a[1:-1, 2:])


def hp(a):
    k = (a[:-2, :-2] + a[:-2, 1:-1] + a[:-2, 2:] + a[1:-1, :-2] + a[1:-1, 1:-1] + a[1:-1, 2:] + a[2:, :-2] + a[2:, 1:-1] + a[2:, 2:]) / 9.0
    return a[1:-1, 1:-1] - k


def shimmer(frames, box):
    vals = []
    for f0, f1 in zip(frames, frames[1:]):
        a, b = hp(lum(f0, box)), hp(lum(f1, box))
        best = None
        for dx in range(-4, 5):   # camera pans horizontally ~1.5 px per frame
            if dx >= 0:
                d = np.abs(a[:, dx:] - b[:, : b.shape[1] - dx]).mean()
            else:
                d = np.abs(a[:, : a.shape[1] + dx] - b[:, -dx:]).mean()
            best = d if best is None else min(best, d)
        vals.append(best)
    return float(np.mean(vals))


def main():
    d, mid = sys.argv[1], int(sys.argv[2])
    r = REGIONS[mid]
    configs = sorted({os.path.basename(p).rsplit("_", 1)[0] for p in glob.glob(os.path.join(d, "*_still.png"))})
    order = ["base"] + [c for c in configs if c != "base"]
    print(f"{'config':14s} {'contrast_far':>12s} {'mean_far':>9s} {'grain':>7s} {'shimmer':>8s}")
    for c in order:
        still = os.path.join(d, f"{c}_still.png")
        if not os.path.exists(still):
            continue
        far = lum(still, r["far"])
        frames = sorted(glob.glob(os.path.join(d, f"{c}_pan*.png")))
        print(f"{c:14s} {far.std():12.2f} {far.mean():9.1f} {lap(lum(still, r['mid'])).mean():7.2f} {shimmer(frames, r['mid']):8.3f}")


main()
