"""Render a schematic placement atlas from TGM + exported runtime geometry."""
import json
import math
from pathlib import Path
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.mapmerge2.dmm import DMM

COLORS = dict(camarilla='#78a5ff', anarchs='#ff735b', sabbat='#d77be4', triads='#8dda87')
COLORS['giovanni-faction'] = '#d8bd72'
manifest = json.loads(Path('modular_vcg/modules/territories/businesses.json').read_text())
for entry in manifest:
    model = DMM.from_file(entry['file'])
    geometry_path = Path(f'data/territory_geometry/{entry["map"]}.json')
    if not geometry_path.exists():
        continue
    geometry = json.loads(geometry_path.read_text())
    offset = geometry.get('map_offset')
    if offset is None:
        first = entry['businesses'][0]
        offset = [geometry['marks'][first['id']][i]-first['marker'][i] for i in range(3)]
    blocked = {tuple(tile[i]-offset[i] for i in range(3)) for tile in geometry['tiles'] if tile[3]}
    panel_w, panel_h, columns, scale, radius = 250, 220, 4, 6, 13
    image = Image.new('RGB', (panel_w*columns, math.ceil(len(entry['businesses'])/columns)*panel_h), '#171b22')
    draw = ImageDraw.Draw(image)
    for index, business in enumerate(entry['businesses']):
        left = index % columns * panel_w
        top = index // columns * panel_h
        mx, my, mz = business['marker']
        draw.text((left+6, top+3), f'{index+1}. {business["name"][:32]}', fill='white')
        draw.text((left+6, top+17), f'{mx}, {my}, z{mz} / {business["owner"]}', fill=COLORS[business['owner']])

        def pixel(c):
            return left+42+(c[0]-mx+radius)*scale, top+38+(my+radius-c[1])*scale

        for x in range(mx-radius, mx+radius+1):
            for y in range(my-radius, my+radius+1):
                c = x, y, mz
                if c not in model.grid:
                    continue
                tile = model.get_tile(c)
                turf = next((a for a in tile if a.startswith('/turf/')), '')
                color = '#31333c'
                if turf.startswith('/turf/open/') and not any(s in turf for s in ['/space', '/openspace']):
                    color = '#71614b' if '/interior' in tile[-1] else '#536753'
                if 'asphalt' in turf:
                    color = '#4c515f'
                if '/water' in turf:
                    color = '#294e67'
                if c in blocked:
                    color = '#11151b'
                if any(a.startswith(('/obj/structure/vampdoor', '/obj/machinery/door')) for a in tile):
                    color = '#b78643'
                px, py = pixel(c)
                draw.rectangle((px, py, px+scale-1, py+scale-1), fill=color)
        for other in entry['businesses']:
            c = other['marker']
            if c[2] != mz or max(abs(c[0]-mx), abs(c[1]-my)) > radius:
                continue
            px, py = pixel(c)
            draw.rectangle((px-1, py-1, px+scale, py+scale), outline=COLORS[other['owner']], width=2)
        cx, cy, cz = business['clerk']
        if cz == mz and max(abs(cx-mx), abs(cy-my)) <= radius:
            px, py = pixel((cx,cy,cz))
            draw.text((px-2, py-3), 'C', fill='#69e3ff')
        px, py = pixel((mx,my,mz))
        draw.rectangle((px-3, py-3, px+scale+2, py+scale+2), outline='white')
        draw.text((left+5, top+203), 'White: mark / cyan C: clerk / amber: door', fill='#aeb7c6')
    target = Path(f'data/territory_geometry/{entry["map"]}_atlas.png')
    image.save(target)
    print(target)
