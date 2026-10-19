"""Seed explicit business links in the three city maps; preserve TGM single-tile diffs.

Run from the repository root with Python 3 and bidict installed. The JSON manifest
records the chosen positions, so future placement edits can be reviewed by ID.
"""
from collections import deque
import json
from pathlib import Path
import random
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.mapmerge2.dmm import DMM, parse_map_atom

MAPS = [
    ('westfield', '_maps/map_files/Vampire/westfield_mall/westfield_mall.dmm'),
    ('sanfangsisco', '_maps/map_files/Vampire/san_fangsisco/sanfangsisco.dmm'),
    ('oakland', '_maps/map_files/Vampire/oakland/bomby_oakland.dmm'),
]


def add_var(atom, key, value):
    path, attributes = parse_map_atom(atom)
    attributes[key] = value
    return path + '{' + ';'.join(f'{k} = {v}' for k, v in attributes.items()) + '}'


def neighbors(c):
    x, y, z = c
    return [(x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z)]


def distance(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1])) if a[2] == b[2] else 10000


def plan_map(map_id, filename):
    random.seed(20261019)
    path = Path(filename)
    model = DMM.from_file(path)
    tiles = {c: model.dictionary[k] for c, k in model.grid.items()}
    if any(any(a.startswith('/obj/structure/city_business') for a in t) for t in tiles.values()):
        raise RuntimeError(f'{filename} already contains business markers; edit the existing TGM tiles instead')

    def walkable(c):
        tile = tiles.get(c, ())
        return any(a.startswith('/turf/open/') and not any(s in a for s in ['/space', '/openspace', '/water']) for a in tile) and not any(
            a.startswith(('/obj/structure/window', '/obj/structure/table', '/obj/structure/closet', '/obj/structure/rack', '/obj/structure/bars', '/obj/machinery/vending')) for a in tile)

    def find_site(origin, used):
        queue = deque([(origin, 0)])
        visited = {origin}
        candidates = []
        while queue:
            coord, steps = queue.popleft()
            if steps > 40:
                continue
            tile = tiles.get(coord, ())
            area = tile[-1] if tile else ''
            service = any(s in area for s in ['/outside', '/maintenance', '/sewer', '/parking_lot']) or area in ['/area/vtm/westfield_mall', '/area/vtm/westfield_mall/interior']
            if service and distance(origin, coord) >= 3 and coord not in used and walkable(coord) and not any(a.startswith(('/obj/structure/vampdoor', '/obj/machinery/door', '/mob/')) for a in tile):
                walls = sum(not walkable(n) for n in neighbors(coord))
                # Prefer a side/service passage to the open pavement, without crossing walls.
                score = steps + (0 if any(s in area for s in ['/maintenance', '/sewer', '/alley']) else 12) + (0 if walls else 8)
                candidates.append((score, coord))
            for other in neighbors(coord):
                if other not in visited and walkable(other):
                    visited.add(other)
                    queue.append((other, steps + 1))
        if not candidates:
            # Some basement shops use stairs/teleport transitions, not a flat route.
            # Keep their point outside the room and record this explicitly for review.
            for coord, tile in tiles.items():
                if distance(origin, coord) > 30 or coord in used or not walkable(coord):
                    continue
                if any(s in tile[-1] for s in ['/outside', '/maintenance', '/sewer']):
                    candidates.append((distance(origin, coord) + 30, coord))
            print('Non-flat entrance:', map_id, origin, '->', min(candidates)[1] if candidates else 'NONE')
        if not candidates:
            for coord, tile in tiles.items():
                planar_distance = max(abs(origin[0] - coord[0]), abs(origin[1] - coord[1]))
                if coord[2] >= origin[2] or planar_distance > 30 or coord in used or not walkable(coord):
                    continue
                if any(s in tile[-1] for s in ['/outside', '/maintenance', '/sewer']):
                    candidates.append((planar_distance + 40 * (origin[2] - coord[2]), coord))
            print('Downstairs entrance:', map_id, origin, '->', min(candidates)[1] if candidates else 'NONE')
        if not candidates:
            raise RuntimeError(f'No service passage near {origin} in {map_id}')
        return min(candidates)[1]

    npcs = {c: next(a for a in t if a.startswith('/mob/living/carbon/human/npc')) for c, t in tiles.items() if any(a.startswith('/mob/living/carbon/human/npc') for a in t)}
    businesses = []
    by_clerk = {}
    claimed_clerks = set()
    for coord, tile in tiles.items():
        outlets = [a for a in tile if a.startswith(('/obj/structure/retail', '/obj/lombard'))]
        # Public police/hospital supplies and Endron's internal service are not city businesses.
        if not outlets or any(s in tile[-1] for s in ['/police', '/clinic', '/endron_facility', '/cog/']):
            continue
        nearby = sorted((distance(coord, c), c) for c in npcs if distance(coord, c) <= 2)
        home = nearby[0][1] if nearby else None
        if home in by_clerk:
            business = by_clerk[home]
            business['outlets'].append(list(coord))
            continue
        if home is None:
            possible = sorted(c for c in tiles if distance(coord, c) <= 1 and walkable(c) and c not in claimed_clerks and c != coord)
            if not possible:
                raise RuntimeError(f'No clerk home for {coord}')
            home = possible[0]
        claimed_clerks.add(home)
        kind = outlets[0].split('{')[0].split('/')[-1]
        area = tile[-1]
        owner = 'camarilla'
        if any(s in area for s in ['/anarch', '/ghetto', '/sewer']) or kind in ['black_market', 'blackmarket', 'smoke_menu']:
            owner = 'anarchs'
        if any(s in area for s in ['/laundromat', '/chinatown']) or kind == 'red_dragon_menu':
            owner = 'triads'
        if any(s in area for s in ['/baali', '/manor', '/tzimisce']):
            owner = 'sabbat'
        business = dict(id=f'{map_id}_{coord[0]}_{coord[1]}_{coord[2]}', name=kind.replace('_', ' ').title(), owner=owner, clerk=list(home), outlets=[list(coord)], area=area)
        businesses.append(business)
        by_clerk[home] = business

    # Additional player-controlled venues, one per connected area on each floor.
    extra_types = ['/strip', '/ventrue', '/toreador', '/brujah', '/malkavian', '/nosferatu_office', '/banu_haqim', '/lasombra', '/elysium', '/dojo']
    visited_venues = set()
    for coord, tile in tiles.items():
        area = tile[-1]
        venue_key = 'strip' if '/strip' in area else area
        if not any(s in area for s in extra_types) or venue_key in visited_venues or not walkable(coord):
            continue
        visited_venues.add(venue_key)
        owned = next((b for b in businesses if b['area'] == area or (venue_key == 'strip' and '/strip' in b['area'])), None)
        if owned:
            if venue_key == 'strip':
                owned['name'] = 'Strip Club'
                owned['owner'] = 'camarilla'
            continue
        existing = [c for c in npcs if tiles[c][-1] == area and c[2] == coord[2] and c not in claimed_clerks]
        home = min(existing) if existing else coord
        claimed_clerks.add(home)
        businesses.append(dict(id=f'{map_id}_venue_{len(businesses)}', name=area.rsplit('/', 1)[-1].replace('_', ' ').title(), owner='triads' if '/dojo' in area else 'camarilla', clerk=list(home), outlets=[], area=area))

    # Primogen offices are not consistently given their own area types. Their
    # existing job landmarks provide stable, map-specific anchors instead.
    primogens = set()
    for coord, tile in tiles.items():
        starts = [a.split('{')[0] for a in tile if a.startswith('/obj/effect/landmark/start/darkpack/primogen/') or a.startswith('/obj/effect/landmark/start/darkpack/voivode/voivode')]
        if not starts or starts[0] in primogens:
            continue
        primogens.add(starts[0])
        if any(distance(coord, tuple(b['clerk'])) <= 5 for b in businesses):
            continue
        homes = sorted((distance(coord, c), c) for c in tiles if distance(coord, c) <= 2 and walkable(c) and c not in claimed_clerks and c != coord)
        if not homes:
            raise RuntimeError(f'No office clerk position near {coord}')
        home = homes[0][1]
        claimed_clerks.add(home)
        clan = starts[0].rsplit('/', 1)[-1]
        businesses.append(dict(id=f'{map_id}_primogen_{clan}', name=f'{clan.title()} Office', owner='sabbat' if clan == 'voivode' else 'camarilla', clerk=list(home), outlets=[], area=tile[-1]))

    # The small test map predates Triad jobs. Give the four existing roles start
    # landmarks in the dojo, without adding a new faction system or new rooms.
    if map_id == 'westfield':
        dojo = sorted(c for c, t in tiles.items() if t[-1].endswith('/dojo') and walkable(c))
        for role, coord in zip(['mountain_master', 'deputy_mountain_master', 'red_pole', 'blue_lanterns'], dojo[::max(1, len(dojo) // 4)]):
            tile = list(model.get_tile(coord))
            tile.insert(0, '/obj/effect/landmark/start/darkpack/triad/' + role)
            model.set_tile(coord, tile)

    used = set()
    for business in businesses:
        origin = tuple(business['outlets'][0] if business['outlets'] else business['clerk'])
        site = find_site(origin, used)
        used.add(site)
        business['marker'] = list(site)
        for c in business['outlets']:
            coord = tuple(c)
            tile = list(model.get_tile(coord))
            for i, atom in enumerate(tile):
                if atom.startswith(('/obj/structure/retail', '/obj/lombard')):
                    tile[i] = add_var(atom, 'territory_id', json.dumps(business['id']))
            model.set_tile(coord, tile)
        marker = '/obj/structure/city_business{' + ';'.join([
            'territory_id = ' + json.dumps(business['id']),
            'business_name = ' + json.dumps(business['name']),
            'owner_faction = ' + json.dumps(business['owner']),
            f'clerk_offset_x = {business["clerk"][0] - site[0]}', f'clerk_offset_y = {business["clerk"][1] - site[1]}', f'clerk_offset_z = {business["clerk"][2] - site[2]}',
        ]) + '}'
        tile = list(model.get_tile(site))
        tile.insert(0, marker)
        model.set_tile(site, tile)
    return dict(map=map_id, file=filename, businesses=businesses), model


if __name__ == '__main__':
    planned = [plan_map(*entry) for entry in MAPS]
    for entry, model in planned:
        model.to_file(entry['file'], tgm=True)
    manifest = [entry for entry, model in planned]
    Path('modular_vcg/modules/territories/businesses.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    for entry in manifest:
        print(entry['map'], len(entry['businesses']), 'businesses')
