"""Extract the three genuinely missing old vampire clothing looks, without duplicates."""
import argparse
from pathlib import Path

from convert import read_dmi, write_dmi
from body_fit import leg_gap_frame


STATES = {'chiefvest', 'nazi', 'ss'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('donor', type=Path)
    args = parser.parse_args()
    source = args.donor / 'code/modules/wod13'
    target = Path('modular_vcg/modules/slim_bodies/icons')
    standard = read_dmi(source / 'worn.dmi')
    for original, output in [('clothing.dmi', 'inventory'), ('worn.dmi', 'worn'),
            ('worn_slim_f.dmi', 'worn_f'), ('onfloor.dmi', 'floor')]:
        sheet = read_dmi(source / original)
        missing = STATES - sheet.keys()
        if missing:
            raise ValueError(f'{original} lacks {sorted(missing)}')
        selected = {state: value for state, value in sheet.items() if state in STATES}
        if output in ('inventory', 'floor'):
            current = 'clothing.dmi' if output == 'inventory' else 'clothing_onfloor.dmi'
            metadata, frames = read_dmi(Path('modular_darkpack/modules/clothes/icons') / current)['bogatyr']
            selected['bogatyr_f'] = (metadata.replace('state = "bogatyr"', 'state = "bogatyr_f"', 1), frames)
        if output == 'worn_f':
            selected = {state: (metadata, [leg_gap_frame(frame, index % 4,
                source=standard[state][1][index]) for index, frame in enumerate(frames)])
                for state, (metadata, frames) in selected.items()}
        write_dmi(target / f'legacy_missing_{output}.dmi', selected)
        print(f'{original}: copied {len(selected)} states')
