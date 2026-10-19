"""Seed explicit business links in the three city maps; preserve TGM single-tile diffs.

Run from the repository root with Python 3 and bidict installed. The default is
one-time discovery and refuses maps that already contain markers. Use --sync to
apply the reviewed JSON manifest without rediscovering existing sites. Discovery
placements still need the runtime geometry review.
"""
import argparse
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
MANIFEST = Path('modular_vcg/modules/territories/businesses.json')
TRIAD_START = '/obj/effect/landmark/start/darkpack/triad/'
TRIAD_JOBS = ('Mountain Master', 'Deputy Mountain Master', 'Red Pole', 'Blue Lanterns')
# Existing family banks; homes are free lobby tiles, not bank interactables.
# Marker positions were reviewed with exported live door/stair geometry and all
# 125 existing markers reserved. Never rediscover the reviewed existing sites.
BANK_SITES = {
    'westfield': ((101, 119, 2), (104, 121, 2)),
    'sanfangsisco': ((72, 154, 2), (74, 143, 2)),
    'oakland': ((176, 120, 2), (170, 120, 2)),
}


def add_var(atom, key, value):
    path, attributes = parse_map_atom(atom)
    attributes[key] = value
    return path + '{' + ';'.join(f'{k} = {v}' for k, v in attributes.items()) + '}'


def neighbors(c):
    x, y, z = c
    return [(x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z)]


def distance(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1])) if a[2] == b[2] else 10000


def seed_policy(entry):
    """Add the small family-bank seed while preserving reviewed positions/IDs."""
    if entry['map'] == 'westfield':
        for business in entry['businesses']:
            if '/dojo' in business['area'] and business['owner'] == 'triads':
                business['owner'] = 'camarilla'
    identifier = entry['map'] + '_giovanni_bank'
    if not any(b['id'] == identifier for b in entry['businesses']):
        home, marker = BANK_SITES[entry['map']]
        entry['businesses'].append(dict(
            id=identifier, name='Giovanni Bank', owner='giovanni-faction',
            clerk=list(home), outlets=[], area='/area/vtm/interior/bianchiBank',
            marker=list(marker)))


def marker_atom(business, original='/obj/structure/city_business'):
    home, site = business['clerk'], business['marker']
    values = {
        'territory_id': json.dumps(business['id']),
        'business_name': json.dumps(business['name']),
        'owner_faction': json.dumps(business['owner']),
        **{f'clerk_offset_{axis}': str(home[i] - site[i]) for i, axis in enumerate('xyz')},
    }
    for key, value in values.items():
        original = add_var(original, key, value)
    return original


def sync_map(entry, model=None):
    """Patch only linked atoms; preserve unrelated tiles and manual map fixes."""
    random.seed(20261019)
    model = model or DMM.from_file(entry['file'])
    changed = False

    def set_tile(coord, tile):
        nonlocal changed
        if tuple(tile) != model.get_tile(coord):
            model.set_tile(coord, tile)
            changed = True

    known_ids = {b['id'] for b in entry['businesses']}
    existing = {}
    for coord in model.grid:
        tile = model.get_tile(coord)
        for atom in tile:
            if not atom.startswith('/obj/structure/city_business'):
                continue
            identifier = json.loads(parse_map_atom(atom)[1]['territory_id'])
            if identifier not in known_ids or identifier in existing:
                raise RuntimeError(f'{entry["map"]}: unlisted/duplicate marker {identifier}')
            existing[identifier] = (coord, atom)
        if entry['map'] == 'westfield':
            # These starts were added by the first territory prototype. This map
            # has no Triad premises; JSON zeroes both roundstart and latejoin.
            set_tile(coord, tuple(a for a in tile if not a.startswith(TRIAD_START)))
    for business in entry['businesses']:
        site = tuple(business['marker'])
        previous = existing.get(business['id'])
        original = previous[1] if previous else '/obj/structure/city_business'
        marker = marker_atom(business, original)
        if previous and previous[0] != site:
            set_tile(previous[0], tuple(a for a in model.get_tile(previous[0]) if a != original))
        tile = model.get_tile(site)
        if previous and previous[0] == site:
            set_tile(site, tuple(marker if a == original else a for a in tile))
        else:
            set_tile(site, (marker, *tile))
        for outlet in business['outlets']:
            coord = tuple(outlet)
            set_tile(coord, tuple(add_var(a, 'territory_id', json.dumps(business['id']))
                                  if a.startswith(('/obj/structure/retail', '/obj/lombard')) else a
                                  for a in model.get_tile(coord)))
    if changed:
        model.to_file(entry['file'], tgm=True)
    return changed


def sync_westfield_jobs():
    path = Path('_maps/westfieldmall.json')
    config = json.loads(path.read_text(encoding='utf-8'))
    before = json.dumps(config)
    for job in TRIAD_JOBS:
        config.setdefault('job_changes', {}).setdefault(job, {}).update(
            spawn_positions=0, total_positions=0)
    if json.dumps(config) != before:
        path.write_text(json.dumps(config, indent='\t') + '\n', encoding='utf-8')


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
            raise RuntimeError(f'No flat service route near {origin} in {map_id}; map an explicit entrance and use review_placement.py with runtime geometry. Never fall back to unconnected floors.')
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
        businesses.append(dict(id=f'{map_id}_venue_{len(businesses)}', name=area.rsplit('/', 1)[-1].replace('_', ' ').title(), owner='triads' if '/dojo' in area and map_id != 'westfield' else 'camarilla', clerk=list(home), outlets=[], area=area))

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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sync', action='store_true', help='Explicitly sync reviewed manifest links and current seed policy; preserve unrelated map atoms')
    args = parser.parse_args()
    if args.sync:
        planned = [(entry, None) for entry in json.loads(MANIFEST.read_text(encoding='utf-8'))]
    else:
        planned = [plan_map(*entry) for entry in MAPS]
    manifest = []
    for entry, model in planned:
        seed_policy(entry)
        # Discovery creates an in-memory model; ensure it is saved even if the
        # subsequent canonical sync happens not to change any linked atoms.
        if model is not None:
            model.to_file(entry['file'], tgm=True)
        sync_map(entry, model)
        manifest.append(entry)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    sync_westfield_jobs()
    for entry in manifest:
        print(entry['map'], len(entry['businesses']), 'businesses')
