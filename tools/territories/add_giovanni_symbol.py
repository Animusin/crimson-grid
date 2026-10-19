"""Reuse the existing Giovanni clan emblem in business marks and credentials.

Run from the repository root with Python 3 and Pillow. Existing frames are
preserved pixel-for-pixel; this only adds/replaces the Giovanni owner state.
"""

from pathlib import Path
import hashlib
import re

from PIL import Image, ImageDraw, PngImagePlugin


ROOT = Path(__file__).resolve().parents[2]
ICONS = ROOT / "modular_vcg/modules/territories/icons"
SOURCE = ROOT / "modular_darkpack/modules/vampire_the_masquerade/icons/vampire_clans.dmi"
STATE = "giovanni-faction"


def read_states(path):
    with Image.open(path) as source:
        metadata = source.info["Description"]
        sheet = source.convert("RGBA")
    width = int(re.search(r"width = (\d+)", metadata)[1])
    height = int(re.search(r"height = (\d+)", metadata)[1])
    frames = {}
    index = 0
    for block in re.split(r"(?=^state = )", metadata, flags=re.M)[1:]:
        name = re.search(r'^state = "(.*)"', block, re.M)[1]
        directions = int(re.search(r"dirs = (\d+)", block)[1])
        count = int(re.search(r"frames = (\d+)", block)[1])
        if directions != 1 or count != 1:
            raise ValueError(f"Expected one direction/frame in {path}: {name}")
        x = index % (sheet.width // width) * width
        y = index // (sheet.width // width) * height
        frames[name] = sheet.crop((x, y, x + width, y + height))
        index += directions * count
    return (width, height), frames


def save_states(path, frames, size):
    sheet = Image.new("RGBA", (size * len(frames), size))
    metadata = f"# BEGIN DMI\nversion = 4.0\n\twidth = {size}\n\theight = {size}\n"
    for index, (name, frame) in enumerate(frames.items()):
        assert frame.size == (size, size), name
        sheet.paste(frame, (index * size, 0))
        metadata += f'state = "{name}"\n\tdirs = 1\n\tframes = 1\n'
    metadata += "# END DMI\n"
    info = PngImagePlugin.PngInfo()
    info.add_text("Description", metadata, zip=True)
    sheet.save(path, format="PNG", pnginfo=info)


def main():
    source_size, source_states = read_states(SOURCE)
    assert source_size == (32, 32)
    emblem = source_states["giovanni"]
    mark = emblem.resize((48, 48), Image.Resampling.NEAREST)
    card = Image.new("RGBA", (32, 32))
    ImageDraw.Draw(card).rounded_rectangle(
        (5, 7, 26, 24), radius=2,
        fill=(40, 40, 45, 255), outline=(175, 175, 180, 255),
    )
    card.alpha_composite(emblem.resize((14, 14), Image.Resampling.NEAREST), (9, 9))

    outputs = {}
    for filename, size, added in (("territories.dmi", 48, mark), ("credentials.dmi", 32, card)):
        path = ICONS / filename
        current_size, frames = read_states(path)
        assert current_size == (size, size)
        preserved = {name: frame.tobytes() for name, frame in frames.items() if name != STATE}
        frames[STATE] = added
        save_states(path, frames, size)
        checked_size, checked_frames = read_states(path)
        assert checked_size == current_size
        assert checked_frames[STATE].tobytes() == added.tobytes()
        for name, pixels in preserved.items():
            assert checked_frames[name].tobytes() == pixels, (filename, name)
        outputs[filename] = checked_frames
        print(f"{filename}: {len(frames)} states, {size}x{size}, all dirs=1/frames=1; "
              f"{len(preserved)} existing frames unchanged")

    labels = {
        "camarilla": "Camarilla", "anarchs": "Anarchs", "sabbat": "Sabbat",
        "triads": "Triads", STATE: "Giovanni",
    }
    preview = Image.new("RGBA", (96 * len(labels), 208), (35, 35, 35, 255))
    draw = ImageDraw.Draw(preview)
    for index, (state, label) in enumerate(labels.items()):
        x = index * 96
        preview.alpha_composite(outputs["territories.dmi"][state].resize((80, 80), Image.Resampling.NEAREST), (x + 8, 0))
        draw.text((x + 6, 86), label, fill="white")
        preview.alpha_composite(outputs["credentials.dmi"][state].resize((64, 64), Image.Resampling.NEAREST), (x + 16, 112))
        draw.text((x + 6, 188), "48px / ID 32px", fill="white")
    preview.save(ICONS / "preview.png")
    print(f"Source Giovanni RGBA SHA256: {hashlib.sha256(emblem.tobytes()).hexdigest()}")
    print(f"Source bbox={emblem.getbbox()}, colors={len(emblem.getcolors())}; floor bbox={mark.getbbox()}")


if __name__ == "__main__":
    main()
