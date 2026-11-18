import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('update_manifest', Path(__file__).parents[2] / 'scripts/update_manifest.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class UpdateManifestTest(unittest.TestCase):
    def test_hash_size_type_and_architecture(self):
        with tempfile.TemporaryDirectory() as folder:
            installer = Path(folder) / 'FastCat arm64-v8a.apk'
            installer.write_bytes(b'abc')
            record = module.describe(installer, 'https://example.com/downloads')
            self.assertEqual(record['sha256'], 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
            self.assertEqual(record['size'], 3)
            self.assertEqual(record['architecture'], 'arm64')
            self.assertEqual(record['package_type'], 'apk')
            self.assertEqual(record['url'], 'https://example.com/downloads/FastCat%20arm64-v8a.apk')

    def test_universal_windows_filename_is_not_labeled_x64(self):
        with tempfile.TemporaryDirectory() as folder:
            installer = Path(folder) / 'FastCat-Windows-3.6.3-Setup.exe'
            installer.write_bytes(b'MZ')
            self.assertEqual(module.describe(installer)['architecture'], 'universal')

if __name__ == '__main__': unittest.main()
