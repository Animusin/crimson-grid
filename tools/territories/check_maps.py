"""Validate business coverage and verify that map edits affect only intended tiles."""
import json
from pathlib import Path
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.mapmerge2.dmm import DMM, parse_map_atom
from tools.territories.plan_maps import TRIAD_JOBS, TRIAD_START

manifest = json.loads(Path('modular_vcg/modules/territories/businesses.json').read_text())
growing = {entry['map']: entry for entry in json.loads(Path('modular_vcg/modules/territories/growing_sites.json').read_text())}
all_ids = set()
for entry in manifest:
    model = DMM.from_file(entry['file'])
    base = DMM.from_bytes(subprocess.check_output(['git', 'show', 'origin/master:' + entry['file']]))
    assert model.size == base.size, entry['file']
    expected_changes = set()
    point_ids = set()
    marker_coords = []
    added_racks = set()
    for site in growing[entry['map']]['sites']:
        rack = tuple(site['rack'])
        tile = model.get_tile(rack)
        assert any(a.startswith('/obj/machinery/smartfridge/drying/rack') for a in tile), ('Missing drying rack', rack)
        assert any(a.startswith(('/turf/open/floor/', '/turf/open/misc/')) for a in tile), ('Rack on wet/closed turf', rack)
        if site['added']:
            added_racks.add(rack)
            expected_changes.add(rack)
            assert tuple(a for a in tile if not a.startswith('/obj/machinery/smartfridge/drying/rack')) == base.get_tile(rack), ('Rack overlaps unrelated map edit', rack)
        for tray in site['trays']:
            tray = tuple(tray)
            assert any(a.startswith('/obj/machinery/hydroponics/simple/') for a in model.get_tile(tray)), ('Missing planter', tray)
            assert tray[2] == rack[2] and max(abs(tray[0]-rack[0]), abs(tray[1]-rack[1])) <= 12, ('Rack too far from planters', tray)
    for business in entry['businesses']:
        identifier = business['id']
        assert identifier not in all_ids, identifier
        all_ids.add(identifier)
        marker_coord = tuple(business['marker'])
        if business['outlets'] and business['clerk'][2] == 2:
            assert marker_coord[2] == 2, (identifier, 'surface shop has a sewer mark')
        assert all(marker_coord[2] != other[2] or max(abs(marker_coord[0]-other[0]), abs(marker_coord[1]-other[1])) >= 2 for other in marker_coords), (identifier, '48px marks overlap')
        marker_coords.append(marker_coord)
        tile = model.get_tile(marker_coord)
        assert any(a.startswith('/turf/open/floor/') for a in tile), identifier
        assert not any(a.startswith(('/obj/structure/', '/obj/machinery/', '/mob/', '/obj/effect/spawner/')) and not a.startswith(('/obj/structure/city_business', '/obj/machinery/light')) for a in tile), (identifier, 'furniture or doorway obscures mark')
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                nearby = model.get_tile((marker_coord[0]+dx, marker_coord[1]+dy, marker_coord[2]))
                assert not any(a.startswith('/turf/') and 'asphalt' in a for a in nearby), (identifier, 'mark on or adjacent to road')
        markers = [a for a in tile if a.startswith('/obj/structure/city_business')]
        assert len(markers) == 1 and f'territory_id = "{identifier}"' in markers[0], identifier
        for axis, offset in zip('xyz', (business['clerk'][i] - business['marker'][i] for i in range(3))):
            assert f'clerk_offset_{axis} = {offset}' in markers[0], (identifier, 'relative clerk position')
        point_ids.add(identifier)
        expected_changes.add(marker_coord)
        assert business['owner'] in ['camarilla', 'anarchs', 'sabbat', 'triads', 'giovanni-faction']
        assert parse_map_atom(markers[0])[1].get('owner_faction') == json.dumps(business['owner']), (identifier, 'marker owner differs from manifest')
        for coord in business['outlets']:
            coord = tuple(coord)
            expected_changes.add(coord)
            assert any(f'territory_id = "{identifier}"' in a for a in model.get_tile(coord)), (identifier, coord)
        home = tuple(business['clerk'])
        assert any(a.startswith('/turf/open/') for a in model.get_tile(home)), (identifier, 'clerk on closed turf')
        if identifier == entry['map'] + '_giovanni_bank':
            assert business['owner'] == 'giovanni-faction' and business['area'] == '/area/vtm/interior/bianchiBank', (identifier, 'family bank seed')
            home_tile = model.get_tile(home)
            assert home_tile[-1].split('{')[0] == business['area'], (identifier, 'clerk outside existing bank')
            assert not any(a.startswith(('/obj/structure/', '/obj/machinery/', '/mob/', '/obj/effect/spawner/', '/obj/effect/landmark/start/')) for a in home_tile), (identifier, 'bank clerk blocks furniture or a player spawn')
            # The marker creates its clerk at LateInitialize; no bank furniture,
            # interactables or terrain need to be replaced by mapped NPCs.
            assert home_tile == base.get_tile(home), (identifier, 'bank clerk home should preserve the baseline tile')
    assert sum(b['owner'] == 'giovanni-faction' for b in entry['businesses']) == 1, (entry['map'], 'one initial family bank')
    starts = {c: tuple(a for a in model.get_tile(c) if a.startswith(TRIAD_START)) for c in model.grid}
    starts = {c: atoms for c, atoms in starts.items() if atoms}
    if entry['map'] == 'westfield':
        assert not starts and not any(b['owner'] == 'triads' for b in entry['businesses']), 'Westfield has no initial Triad presence'
        job_changes = json.loads(Path('_maps/westfieldmall.json').read_text())['job_changes']
        for job in TRIAD_JOBS:
            assert job_changes[job]['spawn_positions'] == job_changes[job]['total_positions'] == 0, (job, 'roundstart and latejoin must both be disabled')
    else:
        baseline_starts = {c: tuple(a for a in base.get_tile(c) if a.startswith(TRIAD_START)) for c in base.grid}
        assert starts == {c: atoms for c, atoms in baseline_starts.items() if atoms}, (entry['map'], 'Triad spawns changed')
    for coord in model.grid:
        current, old = model.get_tile(coord), base.get_tile(coord)
        if current == old:
            continue
        assert coord in expected_changes, ('Unexpected changed tile', coord)
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
    print(f'{entry["map"]}: {len(point_ids)} markers, {len(linked_ids)} retail/buyer businesses, {len(added_racks)} added racks; coverage and tile-only changes OK')
