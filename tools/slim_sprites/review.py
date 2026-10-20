"""Make a review sheet from actual BYOND slim_visual unit-test exports.

Run the server with UNIT_TESTS + SLIM_BODY_TESTS first, then run this from the
repository root. Unlike preview.py, this uses equipped mobs and their real
rendered overlay tree, including bags, accessories, damage and both hands.
"""
import argparse
import base64
import html
import json
from pathlib import Path

from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=Path("data/slim_visual"))
    parser.add_argument("--output", type=Path, default=Path("modular_vcg/modules/slim_bodies/review"))
    parser.add_argument("--scenarios", nargs="+", help="A compact selection from the same actual engine exports")
    parser.add_argument("--directions", nargs="+", choices=("N", "S", "E", "W"), help="Selected views from the same actual engine exports")
    args = parser.parse_args()
    manifest = json.loads((args.input / "manifest.json").read_text())
    if args.scenarios:
        unknown = set(args.scenarios) - set(manifest["scenarios"])
        if unknown:
            raise ValueError(f"Unknown engine scenarios: {sorted(unknown)}")
        manifest["scenarios"] = args.scenarios
    directions = args.directions or manifest["directions"]
    args.output.mkdir(parents=True, exist_ok=True)
    cell, label, top, row_height = 112, 150, 56, 130
    sheet = Image.new("RGB", (label + len(manifest["builds"]) * len(directions) * cell, top + len(manifest["scenarios"]) * row_height), "#262c36")
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 10), "Actual BYOND renders: Standard / Slim, " + " ".join(directions) + "; 3x nearest-neighbor", fill="white")
    panels = []
    for row, scenario in enumerate(manifest["scenarios"]):
        y = top + row * row_height
        draw.text((8, y + 44), scenario.replace("_", " "), fill="white")
        images = []
        for build_index, build in enumerate(manifest["builds"]):
            for column, direction in enumerate(directions):
                direction_index = manifest["directions"].index(direction) + 1
                path = args.input / f"{scenario}_{build}_{direction_index}.png"
                with Image.open(path) as source:
                    frame = source.convert("RGBA")
                    if frame.getbbox() is None:
                        raise ValueError(f"Empty mob render: {path}")
                    zoomed = frame.resize((frame.width * 3, frame.height * 3), Image.Resampling.NEAREST)
                x = label + (build_index * len(directions) + column) * cell
                draw.text((x, y), f"{build} {direction}", fill="#b6c7dd")
                sheet.paste(zoomed, (x, y + 18), zoomed)
                data = base64.b64encode(path.read_bytes()).decode()
                images.append(f'<figure data-build="{build}"><figcaption>{build} {direction}</figcaption><img src="data:image/png;base64,{data}"></figure>')
        panels.append(f'<section><h2>{html.escape(scenario.replace("_", " "))}</h2><div class="row">{"".join(images)}</div></section>')
    sheet.save(args.output / "equipment.png")
    document = """<!doctype html><html lang="en"><meta charset="utf-8"><title>Slim equipment visual review</title>
<style>body{background:#262c36;color:#eee;font:16px sans-serif;margin:20px}section{border-top:1px solid #566}
.row{display:flex;flex-wrap:wrap}figure{margin:8px}img{width:128px;height:128px;object-fit:contain;image-rendering:pixelated;background:repeating-conic-gradient(#34404b 0% 25%,#27333d 0% 50%) 50%/16px 16px}
figcaption{font-size:14px;color:#b6c7dd}label{margin-right:20px}</style>
<h1>Slim equipment visual review</h1><p>Real BYOND mob appearances. Standard and Slim share the same items, hairstyle and skin tone. N / S / E / W.</p>
<label>Zoom <input type="range" min="2" max="8" value="4" oninput="document.querySelectorAll('img').forEach(i=>{i.style.width=32*this.value+'px';i.style.height=32*this.value+'px'})"></label>
<label>Background <input type="color" value="#262c36" oninput="document.body.style.background=this.value;document.querySelectorAll('img').forEach(i=>i.style.background=this.value)"></label>
<label>Build <select onchange="document.querySelectorAll('figure').forEach(i=>i.hidden=this.value!=='Both'&&i.dataset.build!==this.value)"><option>Both</option><option>Standard</option><option>Slim</option></select></label>
""" + "".join(panels) + "</html>"
    (args.output / "equipment.html").write_text(document, encoding="utf-8")
    print(args.output / "equipment.png")
    print(args.output / "equipment.html")


if __name__ == "__main__":
    main()
