"""Review/reposition markers using density and stair links exported by BYOND.

Compile with UNIT_TESTS, BUSINESS_TESTS and BUSINESS_GEOMETRY, run each city,
then copy data/business_geometry.json to data/territory_geometry/<map>.json.
Run this tool from the repo root; --apply writes single-tile TGM changes.
Unlocked doors are allowed on the public approach; locked doors only on the
clerk route. A marker itself can never occupy a doorway.
"""
from collections import deque
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.mapmerge2.dmm import DMM, parse_map_atom


def neighbors(c):
    x, y, z = c
    return [(x+dx, y+dy, z) for dx in range(-1, 2) for dy in range(-1, 2) if dx or dy]


def distance(a, b):
    return max(abs(a[0]-b[0]), abs(a[1]-b[1])) if a[2] == b[2] else 999


def service(tile):
    area = tile[-1].split('{')[0]
    return any(s in area for s in ['/outside', '/maintenance', '/sewer']) or area in (
        '/area/vtm/westfield_mall', '/area/vtm/westfield_mall/interior', '/area/vtm/westfield_mall/skatepark')


def review(entry, apply=False):
    model = DMM.from_file(entry['file'])
    tiles = {c: model.dictionary[k] for c, k in model.grid.items()}
    exported = json.loads(Path(f'data/territory_geometry/{entry["map"]}.json').read_text())
    if exported.get('version') != 2:
        raise ValueError('Re-export geometry with water and live door locks (version 2)')
    first = entry['businesses'][0]
    delta = exported.get('map_offset')
    if delta is None:
        delta = [exported['marks'][first['id']][i] - first['marker'][i] for i in range(3)]
        exported['map_offset'] = delta
        Path(f'data/territory_geometry/{entry["map"]}.json').write_text(json.dumps(exported))

    def normalized(c):
        return tuple(c[i]-delta[i] for i in range(3))

    floors = {}
    links = {}
    locked_doors = set()
    for x, y, z, blocked, door, destinations, restricted in exported['tiles']:
        c = normalized((x, y, z))
        if c not in tiles or blocked:
            continue
        floors[c] = bool(door)
        if restricted:
            locked_doors.add(c)
        for dest in destinations:
            target = normalized(dest)
            if target[2] == c[2]+1 and target[:2] != c[:2]:
                # A stair cannot ascend through a solid ceiling. Early exports
                # recorded the landing even for broken stairs in the base map.
                above = tiles.get((c[0], c[1], c[2]+1), ())
                forced = any(a.startswith('/obj/structure/stairs') and parse_map_atom(a)[1].get('force_open_above') in ('TRUE', '1') for a in tiles[c])
                if not forced and not any(a.startswith('/turf/open/openspace') for a in above):
                    continue
            links.setdefault(c, set()).add(target)
            links.setdefault(target, set()).add(c)

    def flood(start, doors=False, limit=None):
        reached = {c: 0 for c in start}
        queue = deque(start)
        while queue:
            c = queue.popleft()
            if limit is not None and reached[c] >= limit:
                continue
            for n in neighbors(c) + list(links.get(c, ())):
                if n in floors and (doors or n not in locked_doors) and n not in reached:
                    reached[n] = reached[c] + 1
                    queue.append(n)
        return reached

    # The largest street-connected component is the public approach. Isolated
    # courtyards and private rooms cannot qualify just because their area is outside.
    unseen = set(floors) - locked_doors
    components = []
    while unseen:
        component = flood([min(unseen)])
        unseen.difference_update(component)
        street_count = sum('/outside' in tiles[c][-1] for c in component)
        components.append((street_count, len(component), component))
    # Westfield uses its own exterior area family rather than /outside.
    if entry['map'] == 'westfield':
        components = [(sum(tiles[c][-1].split('{')[0] in (
            '/area/vtm/westfield_mall', '/area/vtm/westfield_mall/interior',
            '/area/vtm/westfield_mall/skatepark') for c in component), n, component)
                      for _, n, component in components]
    public = max(components, key=lambda item: item[:2])[2]
    roads = {c for c, t in tiles.items() if any(a.startswith('/turf/') and 'asphalt' in a for a in t)}
    used = []
    report = []
    original_marks = {}
    if apply:
        for b in entry['businesses']:
            old = tuple(b['marker'])
            tile = model.get_tile(old)
            mark = next(a for a in tile if a.startswith('/obj/structure/city_business') and f'territory_id = "{b["id"]}"' in a)
            original_marks[b['id']] = mark
            model.set_tile(old, tuple(a for a in tile if a != mark))
    for b in entry['businesses']:
        home = tuple(b['clerk'])
        # A cashier can stand behind an impassable counter. Trace the customer's
        # approach from adjacent outlet tiles, rather than requiring the cashier
        # to be able to walk through their own counter.
        starts = {home}
        if b.get('public_approach'):
            entrance = tuple(b['public_approach'])
            if entrance not in public:
                raise RuntimeError(f'{b["id"]}: documented approach is not publicly reachable')
            starts = {entrance}
        for outlet in b['outlets']:
            x, y, z = outlet
            starts.update((x+dx, y+dy, z) for dx in range(-1, 2) for dy in range(-1, 2)
                          if (x+dx, y+dy, z) in floors)
        route = flood(starts, doors=True, limit=100)
        candidates = []
        for c, steps in route.items():
            # Surface shops must not acquire a cheaper, unrelated sewer mark.
            # Upper-floor and basement premises can use their public approach.
            if b['outlets'] and home[2] == 2 and c[2] != 2:
                continue
            allowed_area = b.get('approach_area')
            if c not in public or floors.get(c, True) or (not service(tiles[c]) and tiles[c][-1].split('{')[0] != allowed_area):
                continue
            if distance(c, home) < 3 or any(distance(c, other) < 2 for other in used):
                continue
            tile = tiles[c]
            if not any(a.startswith('/turf/open/floor/') for a in tile):
                continue
            # Even non-dense furniture can obscure a floor painting. Keep the
            # entire center tile clear, including random flora spawners.
            if any(a.startswith(('/obj/structure/', '/obj/machinery/', '/mob/', '/obj/effect/spawner/'))
                   and not a.startswith(('/obj/structure/city_business', '/obj/machinery/light')) for a in tile):
                continue
            clearance = min((max(abs(dx), abs(dy)) for dx in range(-7, 8) for dy in range(-7, 8)
                             if (c[0]+dx, c[1]+dy, c[2]) in roads), default=8)
            if clearance < 2:
                continue
            setback = min(clearance, 5)
            sheltered = sum(n not in floors for n in neighbors(c))
            score = steps + 6 * (5-setback) + (0 if sheltered else 4) + 20 * abs(c[2]-home[2])
            candidates.append((score, steps, c, clearance))
        if not candidates:
            raise RuntimeError(f'{b["id"]}: no verified public service passage within 100 steps; '
                               f'clerk component={len(route)}, public={len(public)}, intersection={len(set(route)&set(public))}, '
                               f'components={sorted((a, n) for a,n,_ in components)[-5:]}')
        _, steps, chosen, clearance = min(candidates)
        old = tuple(b['marker'])
        used.append(chosen)
        report.append(dict(id=b['id'], old=old, marker=chosen, approach_steps=steps,
                           route_origin='public_approach' if b.get('public_approach') else 'customer_or_clerk', road_clearance=clearance))
        if apply:
            mark = original_marks[b['id']]
            path, attrs = parse_map_atom(mark)
            for i, axis in enumerate('xyz'):
                attrs[f'clerk_offset_{axis}'] = str(home[i]-chosen[i])
            mark = path + '{' + ';'.join(f'{k} = {v}' for k, v in attrs.items()) + '}'
            model.set_tile(chosen, (mark, *model.get_tile(chosen)))
            b['marker'] = list(chosen)
    if apply:
        model.to_file(Path(entry['file']), tgm=True)
    Path(f'data/territory_geometry/{entry["map"]}_review.json').write_text(json.dumps(report, indent=2))
    print(entry['map'], 'moved', sum(tuple(r['old']) != tuple(r['marker']) for r in report),
          '/', len(report), 'max approach route', max(r['approach_steps'] for r in report))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--map')
    args = parser.parse_args()
    path = Path('modular_vcg/modules/territories/businesses.json')
    manifest = json.loads(path.read_text())
    for entry in manifest:
        if not args.map or args.map == entry['map']:
            review(entry, args.apply)
    if args.apply:
        path.write_text(json.dumps(manifest, indent=2)+'\n')
