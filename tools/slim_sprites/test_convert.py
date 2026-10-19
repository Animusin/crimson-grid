"""DMI file/CLI integration tests, independent of BYOND icon operations."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import re
from PIL import Image, ImageChops
from convert import read_dmi, write_dmi
from body_fit import fit_frame, leg_gap_frame, make_maps


class ConverterTest(unittest.TestCase):
    def test_breast_band_height_retains_the_original_cutout(self):
        maps = make_maps()
        underwear = read_dmi('icons/mob/clothing/underwear.dmi')
        masks = read_dmi('icons/mob/clothing/under/masking_helpers.dmi')
        for direction in range(4):
            bra = ImageChops.multiply(underwear['sports_bra'][1][direction], masks['female_full'][1][direction])
            fitted = fit_frame(bra, direction, maps)
            # Upper chest texture must retain its breast-band rows, rather
            # than jumping early to the empty row below the sports bra.
            if direction == 0:
                self.assertTrue(fitted.getpixel((15,16))[3])
                self.assertEqual(fitted.getpixel((15,17))[3], 0)
                self.assertEqual(fitted.getpixel((15,12))[3], 0)

    def test_real_skirt_hem_keeps_height_and_bridge(self):
        maps = make_maps(draped=True)
        clothes = read_dmi('icons/mob/clothing/under/color.dmi')
        masks = read_dmi('icons/mob/clothing/under/masking_helpers.dmi')
        for direction in range(4):
            source = ImageChops.multiply(clothes['jumpskirt'][1][direction], masks['female_top'][1][direction])
            fitted = fit_frame(source, direction, maps)
            self.assertEqual(source.getbbox()[3], fitted.getbbox()[3])
            for y in range(21,32):
                self.assertEqual(source.getpixel((15,y))[3], fitted.getpixel((15,y))[3])

    def test_native_wardrobe_changes_only_approved_trouser_channel(self):
        standard = read_dmi('modular_darkpack/modules/clothes/icons/worn.dmi')
        donor = read_dmi('modular_darkpack/modules/clothes/icons/worn_slim_f.dmi')
        compatible = read_dmi('modular_vcg/modules/slim_bodies/icons/compatible_worn_f.dmi')
        changed_states = changed_pixels = 0
        for name, (block, frames) in compatible.items():
            dirs = int(re.search(r'dirs = (\d+)', block)[1])
            changed = False
            for index, frame in enumerate(frames):
                for y in range(32):
                    for x in range(32):
                        if frame.getpixel((x,y)) == donor[name][1][index].getpixel((x,y)):
                            continue
                        changed = True
                        changed_pixels += 1
                        self.assertIn(index % dirs, (0,1))
                        self.assertEqual(x, 15)
                        self.assertIn(y, range(23,31))
                        self.assertEqual(standard[name][1][index].getpixel((x,y))[3], 0)
                        self.assertEqual(frame.getpixel((x,y))[3], 0)
            changed_states += changed
        self.assertGreater(changed_states, 0)
        self.assertGreater(changed_pixels, 0)

    def test_anatomical_fit_covers_known_edges_without_cutting_skirts(self):
        maps = make_maps()
        uniforms = read_dmi('icons/mob/clothing/under/color.dmi')
        masks = read_dmi('icons/mob/clothing/under/masking_helpers.dmi')
        body = read_dmi('modular_vcg/modules/slim_bodies/icons/bodyparts.dmi')
        for direction in range(4):
            source = ImageChops.multiply(uniforms['jumpsuit'][1][direction], masks['female_full'][1][direction])
            before = source.tobytes()
            fitted = fit_frame(source, direction, maps)
            self.assertEqual(source.tobytes(), before)
            for part in ('chest_f', 'l_arm', 'r_arm', 'l_leg', 'r_leg'):
                target = body['human_'+part][1][direction]
                for y in range(12, 29):
                    for x in range(32):
                        if target.getpixel((x, y))[3]:
                            if direction == 2 and (x, y) == (16, 28):
                                # Preserve this source hem notch, not body-colored fill.
                                self.assertEqual(fitted.getpixel((x,y))[3], 0)
                                continue
                            self.assertTrue(fitted.getpixel((x, y))[3], (part, direction, x, y))
            if direction in (0, 1):
                for y in range(24, 29):
                    self.assertEqual(fitted.getpixel((15, y))[3], 0)
            # An opaque source bridge is skirt fabric, never an artificial gap.
            skirt = Image.new('RGBA', (32,32), 'red')
            self.assertEqual(fit_frame(skirt, direction, maps).getpixel((15, 25))[3], 255)

    def test_native_gap_correction_preserves_skirt_bridge_and_outer_contour(self):
        native = Image.new('RGBA', (32,32), 'white')
        pants = native.copy()
        for y in range(23,31):
            pants.putpixel((15,y), (0,0,0,0))
        for direction in range(4):
            corrected = leg_gap_frame(native, direction, source=pants)
            skirt = leg_gap_frame(native, direction, source=native)
            self.assertEqual(skirt.tobytes(), native.tobytes())
            for y in range(32):
                for x in range(32):
                    expected = (0,0,0,0) if direction in (0,1) and x == 15 and 23 <= y < 31 else native.getpixel((x,y))
                    self.assertEqual(corrected.getpixel((x,y)), expected)

    def test_body_fit_cli_preserves_animation_and_all_eight_direction_frames(self):
        with tempfile.TemporaryDirectory(prefix='crimson-slim-') as directory:
            root = Path(directory).resolve()
            cells = [Image.new('RGBA', (32,32), (20+i*10, 90, 140, 255)) for i in range(16)]
            block = 'state = "eight"\n\tdirs = 8\n\tframes = 2\n\tdelay = 2,3\n\trewind = 1'
            write_dmi(root/'input.dmi', {'eight': (block, cells)})
            subprocess.run([sys.executable, str(Path(__file__).with_name('convert.py')), str(root/'input.dmi'), str(root/'output.dmi'), '--body-fit'], check=True, capture_output=True)
            output = read_dmi(root/'output.dmi')['eight']
            self.assertEqual(output[0], block)
            self.assertEqual(len(output[1]), 16)
            for actual, source in zip(output[1], cells):
                self.assertEqual(actual.getpixel((16,20)), source.getpixel((16,20)))

    def test_movement_states_and_animation_metadata_survive(self):
        with tempfile.TemporaryDirectory(prefix='crimson-slim-') as directory:
            root = Path(directory).resolve()
            self.assertEqual(root.parent, Path(tempfile.gettempdir()).resolve())
            cells = [Image.new('RGBA', (32,32), (20+i*20, 90, 140, 255)) for i in range(8)]
            standing = 'state = "walk"\n\tdirs = 4\n\tframes = 2\n\tdelay = 2,3\n\trewind = 1'
            moving = standing+'\n\tmovement = 1'
            source = {'walk': (standing, cells), ('walk', 1): (moving, cells[::-1])}
            write_dmi(root/'input.dmi', source)
            subprocess.run([sys.executable, str(Path(__file__).with_name('convert.py')), str(root/'input.dmi'), str(root/'output.dmi')], check=True, capture_output=True)
            output = read_dmi(root/'output.dmi')
            self.assertEqual(len(output), 2)
            for key, (block, frames) in source.items():
                self.assertEqual(output[key][0], block)
                self.assertEqual(len(output[key][1]), 8)
                for actual, original in zip(output[key][1], frames):
                    self.assertEqual(actual.getpixel((16, 5)), original.getpixel((16, 5)))
                    self.assertEqual(actual.getpixel((0, 20))[3], 0)
                    self.assertEqual(actual.getpixel((16, 20)), original.getpixel((16, 20)))

    def test_native_art_cannot_truncate_animation(self):
        with tempfile.TemporaryDirectory(prefix='crimson-slim-') as directory:
            root = Path(directory).resolve()
            self.assertEqual(root.parent, Path(tempfile.gettempdir()).resolve())
            block = 'state = "outfit"\n\tdirs = 4\n\tframes = 2\n\tdelay = 2,4'
            cells = [Image.new('RGBA', (32,32), '#527a91') for _ in range(8)]
            write_dmi(root/'input.dmi', {'outfit': (block, cells)})
            write_dmi(root/'native.dmi', {'outfit': ('state = "outfit"\n\tdirs = 4\n\tframes = 1', cells[:4])})
            subprocess.run([sys.executable, str(Path(__file__).with_name('convert.py')), str(root/'input.dmi'), str(root/'output.dmi'), '--native', str(root/'native.dmi')], check=True, capture_output=True)
            converted = read_dmi(root/'output.dmi')['outfit']
            self.assertEqual(converted[0], block)
            self.assertEqual(len(converted[1]), 8)
            self.assertEqual(converted[1][-1].getpixel((0, 20))[3], 0)


if __name__ == '__main__':
    unittest.main()
