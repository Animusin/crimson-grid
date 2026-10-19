"""Derive an integer UV map from standard/native female anatomy, per direction.

Garment transparency is sampled, never filled from body colors. A trouser's
source inter-leg channel remains transparent; a skirt's opaque bridge remains
opaque. Translation-mask DMIs let BYOND apply this exact map to every frame.
"""
from collections import defaultdict
import math
from pathlib import Path

from PIL import Image

from convert import read_dmi, write_dmi

PARTS = ("chest_f", "l_arm", "r_arm", "l_hand", "r_hand", "l_leg", "r_leg")
STANDARD = Path("icons/mob/human/bodyparts_greyscale.dmi")
NATIVE = Path("modular_vcg/modules/slim_bodies/icons/bodyparts.dmi")
MASKS = Path("modular_vcg/modules/slim_bodies/icons/body_fit.dmi")
SKIRT_MASKS = Path("modular_vcg/modules/slim_bodies/icons/body_fit_skirt.dmi")
SOCK_MASK = Path("modular_vcg/modules/slim_bodies/icons/sock_fit.dmi")
TIP_MASK = Path("modular_vcg/modules/slim_bodies/icons/cloth_tip.dmi")


def leg_gap_frame(frame, direction, bodypart=False, source=None):
    """Open the deliberate native 1px leg channel, never cut skirt fabric.

    The legacy front/back legs overlapped at x=15. Keep their outside contour
    and feet; garment pixels are removed only where the standard garment already
    has a transparent channel between two opaque trouser legs.
    """
    result = frame.copy()
    if direction not in (0, 1):
        return result
    for y in range(23, 31):
        if bodypart or (source is not None and not source.getpixel((15, y))[3]
                        and any(source.getpixel((x, y))[3] for x in range(9, 15))
                        and any(source.getpixel((x, y))[3] for x in range(16, 23))):
            result.putpixel((15, y), (0, 0, 0, 0))
    return result


def opaque(frame):
    return {(x, y) for y in range(32) for x in range(32) if frame.getpixel((x, y))[3]}


def row_span(points, y):
    xs = [x for x, py in points if py == y]
    if not xs:
        closest = min({py for _, py in points}, key=lambda py: abs(py - y))
        xs = [x for x, py in points if py == closest]
    return min(xs), max(xs)


def nearest(value):
    return math.floor(value + .5)


def make_maps(standard=STANDARD, native=NATIVE, draped=False):
    standard, native = read_dmi(standard), read_dmi(native)
    maps = []
    for direction in range(4):
        parts = []
        for name in PARTS:
            source = standard["human_" + name][1][direction]
            target = native["human_" + name][1][direction]
            if source.getbbox() and target.getbbox():
                parts.append((name, opaque(source), opaque(target), source.getbbox(), target.getbbox()))
        mapping = {(x, y): (x, y) for y in range(32) for x in range(32)}
        for y in range(10, 32):
            for x in range(32):
                candidates = []
                for index, (name, source, target, sb, tb) in enumerate(parts):
                    distance = min(abs(x - px) + abs(y - py) for px, py in target)
                    candidates.append((distance, index))
                distance, index = min(candidates)
                if distance > 4:
                    continue
                name, source, target, sb, tb = parts[index]
                sy = nearest(sb[1] + (y - tb[1] + .5) * (sb[3] - sb[1]) / (tb[3] - tb[1]) - .5)
                if name == "chest_f":
                    # Neckline, breast bands and cutouts retain their vertical
                    # position. Only the shorter lower torso needs compression.
                    sy = y if y <= 17 else nearest(17 + (y - 17) * (sb[3] - 18) / (tb[3] - 18))
                if name in ("l_leg", "r_leg"):
                    # The native thigh starts higher, but ankles/feet retain
                    # their height. Anchor the hem instead of shortening pants.
                    sy = y if y >= 27 else nearest(sb[1] + (y - tb[1]) * (26 - sb[1]) / (26 - tb[1]))
                sy = max(0, min(31, sy))
                tl, tr = row_span(target, y)
                sl, sr = row_span(source, sy)
                sx = nearest(sl + (x - tl + .5) * (sr - sl + 1) / (tr - tl + 1) - .5)
                if (x, y) in target and (sx, sy) not in source:
                    # Shape details such as the breast tip must map to actual
                    # source anatomy, rather than outside its clothing edge.
                    sx, sy = min(source, key=lambda p: abs(p[0] - sx) + abs(p[1] - sy))
                mapping[x, y] = max(0, min(31, sx)), sy
            # The gap is its own UV interval, rather than a nearest-leg sample.
            # Sampling its source alpha preserves both pants and skirt bridges.
            legs = [part for part in parts if part[0] in ("l_leg", "r_leg")]
            if len(legs) == 2 and all(any(py == y for _, py in part[2]) for part in legs):
                legs.sort(key=lambda p: sum(row_span(p[2], y)))
                left, right = legs
                gap_left = row_span(left[2], y)[1] + 1
                gap_right = row_span(right[2], y)[0] - 1
                if gap_left <= gap_right:
                    source_y = mapping[gap_left - 1, y][1]
                    source_left = row_span(left[1], source_y)[1] + 1
                    source_right = row_span(right[1], source_y)[0] - 1
                    for x in range(gap_left, gap_right + 1):
                        sx = nearest(source_left + (x - gap_left + .5) * max(1, source_right - source_left + 1) / (gap_right - gap_left + 1) - .5)
                        mapping[x, y] = max(0, min(31, sx)), source_y
        if draped:
            # A skirt hangs from the hips; its hem must not follow a trouser's
            # higher thighs. Fit its width uniformly to the torso, preserving
            # source hem rows, fabric bridges and decorative alpha.
            source = standard['human_chest_f'][1][direction].getbbox()
            target = native['human_chest_f'][1][direction].getbbox()
            source_center = (source[0] + source[2] - 1) / 2
            target_center = (target[0] + target[2] - 1) / 2
            ratio = (source[2] - source[0]) / (target[2] - target[0])
            for y in range(21, 32):
                for x in range(32):
                    mapping[x, y] = max(0, min(31, nearest(source_center + (x-target_center)*ratio))), y
        maps.append(mapping)
    return maps


def fit_frame(frame, direction, maps=None):
    mapping = (maps or make_maps())[direction]
    output = Image.new("RGBA", (32, 32))
    for target, source in mapping.items():
        output.putpixel(target, frame.getpixel(source))
    if direction in (2, 3):
        x, y = (20 if direction == 2 else 11), 13
        outward = 1 if direction == 2 else -1
        # Broad armor/outerwear continues above, below or outward and retains
        # its art. Only an isolated exterior point is an extrapolation artifact.
        if not any(output.getpixel(p)[3] for p in [(x, y-1), (x, y+1), (x+outward, y)]):
            output.putpixel((x, y), (0, 0, 0, 0))
    return output


def write_masks(path=MASKS, maps=None):
    maps = maps or make_maps()
    groups = defaultdict(lambda: [Image.new("RGBA", (32, 32)) for _ in range(4)])
    for direction, mapping in enumerate(maps):
        for (x, y), (sx, sy) in mapping.items():
            if y < 10:
                continue
            dx, dy = x - sx, sy - y  # BYOND vertical coordinates grow upward.
            groups[dx, dy][direction].putpixel((x, y), (255, 255, 255, 255))
    states = {f"{dx}_{dy}": (f'state = "{dx}_{dy}"\n\tdirs = 4\n\tframes = 1', frames)
              for (dx, dy), frames in sorted(groups.items())}
    write_dmi(path, states)
    return len(states)


def write_sock_mask(path=SOCK_MASK):
    body = read_dmi(NATIVE)
    frames = []
    for direction in range(4):
        frame = Image.new('RGBA', (32,32))
        # Pantyhose can reach the waist; retain that lower torso as well as legs.
        for part in ('chest_f', 'l_leg', 'r_leg'):
            for x, y in opaque(body['human_'+part][1][direction]):
                if y >= 18:
                    frame.putpixel((x,y), (255,255,255,255))
        frames.append(frame)
    write_dmi(path, {'socks': ('state = "socks"\n\tdirs = 4\n\tframes = 1', frames)})


def write_tip_masks(path=TIP_MASK):
    keep = [Image.new('RGBA', (32,32), 'white') for _ in range(4)]
    east = [Image.new('RGBA', (32,32)) for _ in range(4)]
    west = [Image.new('RGBA', (32,32)) for _ in range(4)]
    keep[2].putpixel((20,13), (0,0,0,0))
    keep[3].putpixel((11,13), (0,0,0,0))
    east[2].putpixel((20,13), (255,255,255,255))
    west[3].putpixel((11,13), (255,255,255,255))
    write_dmi(path, {name: (f'state = "{name}"\n\tdirs = 4\n\tframes = 1', frames)
                     for name, frames in [('keep', keep), ('east', east), ('west', west)]})


if __name__ == "__main__":
    print(f"{write_masks()} anatomy translation masks written to {MASKS}")
    print(f"{write_masks(SKIRT_MASKS, make_maps(draped=True))} draped translation masks written to {SKIRT_MASKS}")
    write_sock_mask()
    write_tip_masks()
