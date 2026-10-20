"""Map every old vampire clothing definition onto current items, avoiding aliases.

python tools/slim_sprites/audit_clothing.py ../World-of-Darkness-13
"""
import argparse
import json
from pathlib import Path
import re

from convert import read_dmi


ALIASES = {
    '/obj/item/clothing/under/vampire/agent': '/obj/item/clothing/under/vampire/hound',
    '/obj/item/clothing/suit/vampire/bogatyr': '/obj/item/clothing/suit/vampire/bogatyr/heavy',
    '/obj/item/clothing/head/vampire/bogatyr': '/obj/item/clothing/head/vampire/bogatyr/heavy',
}
for suffix in ['', '/police', '/officer', '/fbi']:
    ALIASES['/obj/item/storage/belt/holster/detective/vampire' + suffix] = '/obj/item/storage/belt/holster/detective/darkpack' + suffix
RESTORED = {
    '/obj/item/clothing/under/vampire/nazi',
    '/obj/item/clothing/head/vampire/nazi',
    '/obj/item/clothing/suit/vampire/vest/police/chief',
}


def parse_types(text):
    result = {}
    for match in re.finditer(r'^(/obj/item/[\w/]+)[ \t]*(?://[^\n]*)?\n(.*?)(?=^/|\Z)', text, re.M | re.S):
        result.setdefault(match[1], {}).update(dict(re.findall(
            r'^[ \t]+(name|icon_state|worn_icon_state|parent_type)\s*=\s*(.*)$', match[2], re.M)))
    return result


def value(types, path, key):
    visited = set()
    while path and path not in visited:
        visited.add(path)
        attrs = types.get(path, {})
        if key in attrs:
            return attrs[key].strip().strip('"')
        path = attrs.get('parent_type', path.rpartition('/')[0])
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('donor', type=Path)
    args = parser.parse_args()
    donor_file = args.donor / 'code/modules/wod13/clothcode.dm'
    old = parse_types(donor_file.read_text())
    current = {}
    files = {Path(file.replace('\\', '/')) for file in re.findall(
        r'^#include "([^"\n]+\.dm)"', Path('tgstation.dme').read_text(), re.M)}
    # This one new source can be audited before the canonical include is added.
    files.add(Path('modular_vcg/modules/slim_bodies/code/legacy_clothing.dm'))
    for file in sorted(files):
        for path, attrs in parse_types(file.read_text(errors='replace')).items():
            current.setdefault(path, {}).update(attrs)
    rows = []
    for path in old:
        target = ALIASES.get(path, path)
        if target not in current:
            raise ValueError(f'Unmapped legacy item: {path}')
        rows.append({'old_type': path, 'current_type': target,
            'status': 'restored' if path in RESTORED else 'renamed' if path in ALIASES else 'existing',
            'old_name': value(old, path, 'name'), 'current_name': value(current, target, 'name'),
            'old_state': value(old, path, 'icon_state'),
            'current_state': value(current, target, 'worn_icon_state') or value(current, target, 'icon_state')})
    normal = read_dmi('modular_darkpack/modules/clothes/icons/worn.dmi')
    slim = read_dmi('modular_darkpack/modules/clothes/icons/worn_slim_f.dmi')
    footwear = []
    for row in rows:
        if '/shoes/' not in row['old_type']:
            continue
        state = row['current_state']
        assert state in normal, row
        for sheet in (normal, slim) if state in slim else (normal,):
            assert re.findall(r'(?:dirs|frames) = (\d+)', sheet[state][0]) == ['4', '1'], row
        footwear.append({'type': row['current_type'], 'state': state, 'dirs': 4, 'frames': 1,
            'slim_art': 'native' if state in slim else 'fitted fallback'})
    assert len(rows) == 202 and len(footwear) == 14
    manifest = {'donor_repository': 'Animusin/World-of-Darkness-13',
        'donor_revision': '39142647cb5de07c201e9242a7474fd9d66bd5bf',
        'donor_source': 'code/modules/wod13/clothcode.dm', 'items': rows, 'footwear': footwear}
    output = Path('modular_vcg/modules/slim_bodies/legacy_clothing_manifest.json')
    output.write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'{len(rows)} legacy definitions mapped: {len(rows)-len(ALIASES)-len(RESTORED)} existing, {len(ALIASES)} renamed, {len(RESTORED)} restored; {len(footwear)} footwear layouts verified.')


if __name__ == '__main__':
    main()
