"""Manifest id and config paths use the pizza.dirty.* reverse-domain id."""
import json
import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class TestManifest(unittest.TestCase):
    def test_manifest_id(self):
        with open(os.path.join(ROOT, "manifest.json")) as f:
            manifest = json.load(f)
        self.assertEqual(manifest["id"], "pizza.dirty.clock")

    def test_config_and_cache_paths_use_new_id(self):
        # fetch-events.py is run as a script (hyphenated name), so read
        # it rather than importing it.
        with open(os.path.join(ROOT, "fetch-events.py")) as f:
            source = f.read()
        self.assertIn("pizza.dirty.clock", source)
        self.assertIn('DEFAULT_CONFIG_PATH = os.path.expanduser("~/.config/pizza.dirty.clock/calendars.json")', source)
        self.assertIn('DEFAULT_CACHE_PATH = os.path.expanduser("~/.cache/pizza.dirty.clock/events.json")', source)
        self.assertNotIn("deoxizn.clock", source)


if __name__ == "__main__":
    unittest.main()
