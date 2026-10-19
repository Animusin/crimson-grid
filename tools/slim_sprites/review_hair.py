"""Build a hairstyle review sheet from actual slim_hair engine-test exports."""
import argparse
import base64
import html
import json
from pathlib import Path

from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, default=Path('data/slim_hair'))
    parser.add_argument('--output', type=Path, default=Path('modular_vcg/modules/slim_bodies/review'))
    args = parser.parse_args()
    manifest = json.loads((args.input / 'manifest.json').read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    rows = [(style, color) for style in manifest['styles'] for color in manifest['colors']]
    cell, label, top, row_height = 140, 175, 48, 158
    sheet = Image.new('RGB', (label + 8 * cell, top + (len(rows) + 1) * row_height), '#262c36')
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 10), 'Actual BYOND mob renders: existing / native slim hair, N S E W; 4x nearest-neighbor', fill='white')
    sections = []

    def panel(path, x, y, caption):
        with Image.open(path) as source:
            frame = source.convert('RGBA')
            if frame.getbbox() is None:
                raise ValueError(f'Empty render: {path}')
            zoomed = frame.resize((frame.width * 4, frame.height * 4), Image.Resampling.NEAREST)
        draw.text((x, y), caption, fill='#b6c7dd')
        sheet.paste(zoomed, (x, y + 18), zoomed)
        encoded = base64.b64encode(path.read_bytes()).decode()
        return f'<figure><figcaption>{html.escape(caption)}</figcaption><img src="data:image/png;base64,{encoded}"></figure>'

    for row, (style, color) in enumerate(rows):
        y = top + row * row_height
        title = f"{manifest['styles'][style]} / {color}"
        draw.text((8, y + 55), title, fill='white')
        draw.text((8, y + 72), manifest['colors'][color], fill=manifest['colors'][color])
        images = []
        for build_index, build in enumerate(manifest['builds']):
            for index, direction in enumerate(manifest['directions'], 1):
                images.append(panel(args.input / f'{style}_{color}_{build}_{index}.png',
                    label + (build_index * 4 + index - 1) * cell, y, f'{build} {direction}'))
        sections.append(f'<section><h2>{html.escape(title)}</h2><div>{"".join(images)}</div></section>')
    y = top + len(rows) * row_height
    draw.text((8, y + 55), 'Ponytail: real beret', fill='white')
    draw.text((8, y + 72), 'and cyan gradient', fill='#21b8ce')
    images = [panel(args.input / f'hat_gradient_Slim_{index}.png', label + (index - 1) * cell, y, f'Slim {direction}')
        for index, direction in enumerate(manifest['directions'], 1)]
    sections.append(f'<section><h2>Real beret and gradient</h2><div>{"".join(images)}</div></section>')
    sheet.save(args.output / 'hair.png')
    document = '''<!doctype html><html lang="en"><meta charset="utf-8"><title>Native slim hair review</title>
<style>body{background:#262c36;color:#eee;font:16px sans-serif;margin:20px}section{border-top:1px solid #566}
section>div{display:flex;flex-wrap:wrap}figure{margin:8px}img{width:160px;height:160px;image-rendering:pixelated}
figcaption{color:#b6c7dd;font-size:14px}</style><h1>Native slim hair review</h1>
<p>Real BYOND mobs, same hairstyle and tint. Standard / Slim, N S E W. Brown and cyan; final row has a real beret and hair gradient.</p>
<label>Background <input type="color" value="#262c36" oninput="document.body.style.background=this.value"></label>
''' + ''.join(sections) + '</html>'
    (args.output / 'hair.html').write_text(document, encoding='utf-8')
    print(args.output / 'hair.png')
    print(args.output / 'hair.html')


if __name__ == '__main__':
    main()
