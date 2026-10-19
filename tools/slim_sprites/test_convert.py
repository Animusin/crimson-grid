"""DMI file/CLI integration tests, independent of BYOND icon operations."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from PIL import Image
from convert import read_dmi, write_dmi


class ConverterTest(unittest.TestCase):
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
