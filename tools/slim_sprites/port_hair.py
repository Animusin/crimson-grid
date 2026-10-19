"""Extract only the old vampire build's registered, native slim hair artwork.

python tools/slim_sprites/port_hair.py ../World-of-Darkness-13
The donor revision and license are recorded in HAIR_PROVENANCE.md.
"""
import argparse
from pathlib import Path
import re

from convert import read_dmi, write_dmi


def native_states(donor):
    text = (donor / 'code/modules/mob/dead/new_player/sprite_accessories.dm').read_text()
    names = set()
    for match in re.finditer(r'^/datum/sprite_accessory/hair/[^\s]+\n(.*?)(?=^/|\Z)', text, re.M | re.S):
        state = re.search(r'^\ticon_state = "([^"]+)"', match[1], re.M)
        if state:
            names.add(state[1])
    native = read_dmi(donor / 'icons/mob/human_face_f.dmi')
    missing = names - native.keys()
    if missing:
        raise ValueError(f'Missing donor slim hair states: {sorted(missing)}')
    return {name: native[name] for name in native if name in names}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('donor', type=Path)
    parser.add_argument('--output', type=Path, default=Path('modular_vcg/modules/slim_bodies/icons/hair.dmi'))
    args = parser.parse_args()
    states = native_states(args.donor)
    if len(states) != 319:
        raise ValueError(f'Expected 319 registered legacy hair states, got {len(states)}')
    write_dmi(args.output, states)
    print(f'{len(states)} native slim hair states written to {args.output}')
