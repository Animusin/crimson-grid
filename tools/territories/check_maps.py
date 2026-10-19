"""Validate business coverage and verify that map edits affect only intended tiles."""
import json
from pathlib import Path
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.mapmerge2.dmm import DMM

manifest = json.loads(Path('modular_vcg/modules/territories/businesses.json').read_text())
all_ids = set()
for entry in manifest:
    model = DMM.from_file(entry['file'])
    base = DMM.from_bytes(subprocess.check_output(['git', 'show', 'origin/master:' + entry['file']]))
    assert model.size == base.size, entry['file']
    expected_changes = set()
    point_ids = set()
    for business in entry['businesses']:
        identifier = business['id']
        assert identifier not in all_ids, identifier
        all_ids.add(identifier)
        marker_coord = tuple(business['marker'])
        tile = model.get_tile(marker_coord)
        assert any(a.startswith('/turf/open/') and '/openspace' not in a and '/space' not in a for a in tile), identifier
        markers = [a for a in tile if a.startswith('/obj/structure/city_business')]
        assert len(markers) == 1 and f'territory_id = "{identifier}"' in markers[0], identifier
        for axis, offset in zip('xyz', (business['clerk'][i] - business['marker'][i] for i in range(3))):
            assert f'clerk_offset_{axis} = {offset}' in markers[0], (identifier, 'relative clerk position')
        point_ids.add(identifier)
        expected_changes.add(marker_coord)
        assert business['owner'] in ['camarilla', 'anarchs', 'sabbat', 'triads']
        for coord in business['outlets']:
            coord = tuple(coord)
            expected_changes.add(coord)
            assert any(f'territory_id = "{identifier}"' in a for a in model.get_tile(coord)), (identifier, coord)
        home = tuple(business['clerk'])
        assert any(a.startswith('/turf/open/') for a in model.get_tile(home)), (identifier, 'clerk on closed turf')
    for coord in model.grid:
        current, old = model.get_tile(coord), base.get_tile(coord)
        if current == old:
            continue
        if coord not in expected_changes:
            assert entry['map'] == 'westfield' and any(a.startswith('/obj/effect/landmark/start/darkpack/triad/') for a in current), ('Unexpected changed tile', coord)
        assert [a for a in current if a.startswith(('/turf/', '/area/'))] == [a for a in old if a.startswith(('/turf/', '/area/'))], ('Terrain changed', coord)
    linked_ids = set()
    for coord, key in model.grid.items():
        tile = model.dictionary[key]
        eligible = [a for a in tile if a.startswith(('/obj/structure/retail', '/obj/lombard'))]
        if any(s in tile[-1] for s in ['/police', '/clinic', '/endron_facility', '/cog/']):
            continue
        for outlet in eligible:
            match = re.search(r'territory_id = "([^"]+)"', outlet)
            assert match and match[1] in point_ids, ('Unlinked outlet', coord, outlet)
            linked_ids.add(match[1])
    assert Path(entry['file']).read_text(encoding='utf-8').startswith('//MAP CONVERTED BY dmm2tgm.py'), 'TGM header is required for single-tile diffs'
    print(f'{entry["map"]}: {len(point_ids)} markers, {len(linked_ids)} retail/buyer businesses; coverage and tile-only changes OK')
