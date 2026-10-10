import unittest
from pathlib import Path
import runpy

asset_path = runpy.run_path(str(Path(__file__).with_name("prepare-demo.py")))["asset_path"]


class AssetPathTest(unittest.TestCase):
    def test_archive_paths_are_portable(self):
        self.assertEqual(asset_path("data\\GLOBAL\\UI\\font.DC6"), "data/global/ui/font.dc6")

    def test_extraction_cannot_escape_data_root(self):
        for name in ("../file", "/data/file", "data/../../file", "data//file", "data/./file"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                asset_path(name)


if __name__ == "__main__":
    unittest.main()
