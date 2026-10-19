"""Pixel-preserving 32x32 DMI conversion, or native bodypart extraction.

python tools/slim_sprites/convert.py source.dmi output.dmi [--native native.dmi]
python tools/slim_sprites/convert.py old_bodyparts.dmi output.dmi --extract-body

Native states take priority. Other states retain all metadata, directions,
animation frames and delays; only BYOND rows 1..22 are narrowed from 32 to 28.
"""
import argparse
import math
from pathlib import Path
import re
from PIL import Image, PngImagePlugin


def read_dmi(path):
    with Image.open(path) as opened:
        description = opened.info['Description']
        image = opened.convert('RGBA')
    width = int(re.search(r'\bwidth = (\d+)', description)[1])
    height = int(re.search(r'\bheight = (\d+)', description)[1])
    if (width, height) != (32, 32):
        raise ValueError('This converter accepts only 32x32 DMI files')
    columns = image.width // width
    states = {}
    offset = 0
    for block in re.split(r'\n(?=state = )', description)[1:]:
        block = block.split('# END DMI')[0].rstrip()
        name = re.match(r'state = "([^"]*)"', block)[1]
        dirs = int(re.search(r'dirs = (\d+)', block)[1])
        frames = int(re.search(r'frames = (\d+)', block)[1])
        cells = []
        for i in range(offset, offset + dirs*frames):
            x, y = i % columns * width, i // columns * height
            cells.append(image.crop((x, y, x+width, y+height)))
        # DMI can have a standing and moving state with the same name. Keep
        # every block, including repeated legacy blocks, in source order.
        key = name
        occurrence = 1
        while key in states:
            key = (name, occurrence)
            occurrence += 1
        states[key] = (block, cells)
        offset += dirs*frames
    return states


def convert_frame(frame):
    result = frame.copy()
    result.paste((0, 0, 0, 0), (0, 10, 32, 32))
    for column in range(28):
        source = math.floor((column+0.5)*32/28)
        result.paste(frame.crop((source, 10, source+1, 32)), (column+2, 10))
    return result


def write_dmi(path, states):
    cells = [cell for _, frames in states.values() for cell in frames]
    columns = max(1, math.ceil(math.sqrt(len(cells))))
    image = Image.new('RGBA', (columns*32, math.ceil(len(cells)/columns)*32))
    for i, frame in enumerate(cells):
        image.paste(frame, (i % columns*32, i // columns*32))
    description = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    description += '\n'.join(block for block, _ in states.values()) + '\n# END DMI\n'
    metadata = PngImagePlugin.PngInfo()
    metadata.add_text('Description', description, zip=True)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format='PNG', pnginfo=metadata)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source')
    parser.add_argument('output')
    parser.add_argument('--native', action='append', default=[], help='Native sheet, in priority order; repeatable')
    parser.add_argument('--extract-body', action='store_true')
    parser.add_argument('--native-only', action='store_true', help='Extract only layout-compatible native states')
    args = parser.parse_args()
    if Path(args.source).resolve() == Path(args.output).resolve():
        parser.error('Use a separate output path')
    source = read_dmi(args.source)
    if args.extract_body:
        output = {name[1:]: (block.replace('state = "shuman_', 'state = "human_', 1), frames)
                  for name, (block, frames) in source.items() if isinstance(name, str) and name.startswith('shuman_')}
        if len(output) != 10:
            raise ValueError('Expected ten native slim human bodypart states')
    else:
        native_sheets = [read_dmi(path) for path in args.native]
        if args.native_only and not args.native:
            parser.error('--native-only requires --native')
        output = {}
        for name, (block, frames) in source.items():
            replacement = next((sheet[name] for sheet in native_sheets if name in sheet
                and len(sheet[name][1]) == len(frames)
                and re.findall(r'(?:dirs|frames) = .*', sheet[name][0])
                == re.findall(r'(?:dirs|frames) = .*', block)
                and re.findall(r'movement = .*', sheet[name][0]) == re.findall(r'movement = .*', block)), None)
            # Source timing/layout are authoritative. Never silently truncate frames.
            if replacement:
                output[name] = (block, replacement[1])
            elif not args.native_only:
                output[name] = (block, [convert_frame(frame) for frame in frames])
    write_dmi(args.output, output)
    print(f'{len(output)} states written to {args.output}')


if __name__ == '__main__':
    main()
