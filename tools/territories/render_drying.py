"""Render review crops for every mapped multi-planter growing site."""
import json
import math
from pathlib import Path
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.mapmerge2.dmm import DMM

entries = json.loads(Path('modular_vcg/modules/territories/growing_sites.json').read_text())
sites = [(entry, site) for entry in entries for site in entry['sites']]
columns, width, height, radius, scale = 4, 280, 292, 12, 10
image = Image.new('RGB', (columns*width, math.ceil(len(sites)/columns)*height), '#171b22')
draw = ImageDraw.Draw(image)
models = {entry['map']: DMM.from_file(entry['file']) for entry in entries}
for index, (entry, site) in enumerate(sites):
    model = models[entry['map']]
    left, top = (index % columns)*width, (index // columns)*height
    mx, my, mz = site['rack']
    draw.text((left+5, top+2), f'{index+1}. {entry["map"]}: {len(site["trays"])} planters', fill='white')
    draw.text((left+5, top+16), f'Rack ({mx},{my},z{mz}): '+('added' if site['added'] else 'existing'), fill='#ffc26a')

    def pixel(c):
        return left+15+(c[0]-mx+radius)*scale, top+32+(my+radius-c[1])*scale

    for x in range(mx-radius, mx+radius+1):
        for y in range(my-radius, my+radius+1):
            c = x, y, mz
            if c not in model.grid:
                continue
            tile = model.get_tile(c)
            turf = next((a for a in tile if a.startswith('/turf/')), '')
            color = '#11151b'
            if turf.startswith(('/turf/open/floor/', '/turf/open/misc/')):
                color = '#71614b' if '/interior' in tile[-1] else '#536753'
            if '/water' in turf:
                color = '#294e67'
            if any(a.startswith(('/obj/structure/', '/obj/machinery/'))
                   and not a.startswith(('/obj/machinery/light', '/obj/structure/city_business')) for a in tile):
                color = '#2c3036'
            if any(a.startswith(('/obj/structure/vampdoor', '/obj/machinery/door')) for a in tile):
                color = '#b78643'
            px, py = pixel(c)
            draw.rectangle((px, py, px+scale-1, py+scale-1), fill=color)
    for tray in site['trays']:
        px, py = pixel(tray)
        draw.rectangle((px, py, px+scale-1, py+scale-1), fill='#5cba72')
    px, py = pixel(site['rack'])
    draw.rectangle((px-2, py-2, px+scale+1, py+scale+1), outline='#ffc26a', width=2)
    draw.text((px+1, py-1), 'R', fill='white')
    draw.text((left+5, top+281), 'Green: planters / R: rack / amber: door', fill='#aeb7c6')
target = Path('modular_vcg/modules/territories/review/drying.png')
image.save(target)
print(target)
