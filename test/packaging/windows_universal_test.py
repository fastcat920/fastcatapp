import importlib.util
import json
import struct
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).parents[2]
spec = importlib.util.spec_from_file_location('windows_universal', ROOT / 'scripts/windows_universal.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def pe(path, machine):
    data = bytearray(128)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 0x3c, 64)
    data[64:68] = b'PE\0\0'
    struct.pack_into('<H', data, 68, machine)
    path.write_bytes(data)


class UniversalWindowsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.x64 = self.root / 'x64'
        self.arm64 = self.root / 'arm64'
        for folder, arch in [(self.x64, 'x64'), (self.arm64, 'arm64')]:
            folder.mkdir()
            for name in ['FastCat.exe', 'flutter_windows.dll', 'fastcatCore.exe', 'fastcatHelperService.exe']:
                pe(folder / name, module.MACHINES[arch])
            (folder / 'data').mkdir()
            (folder / 'data/flutter_assets').write_bytes(b'assets')
            module.record(folder, arch, 'same-commit')
        self.runtime = self.root / 'runtime'
        self.runtime.mkdir()
        for arch in ['x64', 'arm64']:
            (self.runtime / f'vc_redist.{arch}.exe').write_bytes(b'CI verifies Microsoft signature')

    def test_combines_matching_payloads_and_selects_one_architecture(self):
        script, installer = module.render(self.x64, self.arm64, self.root / 'dist', self.runtime)
        source = script.read_text(encoding='utf-8-sig')
        self.assertIn('Setup.exe', installer.name)
        self.assertNotIn('{{', source)
        self.assertNotIn('{%', source)
        self.assertIn('ArchitecturesAllowed=x64os or arm64', source)
        self.assertIn(f'Source: "{self.x64.resolve()}\\*"', source)
        self.assertIn(f'Source: "{self.arm64.resolve()}\\*"', source)
        self.assertEqual(source.count('Check: not IsArm64'), 3)
        self.assertEqual(source.count('Check: IsArm64'), 3)
        self.assertIn('Check: IsInAppUpdate', source)
        self.assertIn('stop fastcatHelperService', source)
        self.assertNotIn('  KillProcesses;\n  Result := True;', source)

    def test_refuses_mixed_build_commits(self):
        data = json.loads((self.arm64 / 'payload-info.json').read_text())
        data['commit'] = 'other-commit'
        (self.arm64 / 'payload-info.json').write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'different commits'):
            module.render(self.x64, self.arm64, self.root / 'dist', self.runtime)

    def test_refuses_an_unexpected_ci_commit(self):
        with self.assertRaisesRegex(ValueError, 'commit mismatch'):
            module.validate(self.x64, 'x64', 'unexpected-commit')

    def test_refuses_tampered_or_missing_payload_files(self):
        (self.x64 / 'FastCat.exe').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'integrity mismatch'):
            module.validate(self.x64, 'x64')

    def test_refuses_wrong_architecture_even_with_matching_receipt(self):
        pe(self.arm64 / 'fastcatCore.exe', module.MACHINES['x64'])
        with self.assertRaisesRegex(ValueError, 'incorrect arm64'):
            module.record(self.arm64, 'arm64', 'same-commit')

    def test_refuses_forged_receipt_for_a_wrong_architecture_plugin(self):
        plugin = self.arm64 / 'plugin.dll'
        pe(plugin, module.MACHINES['x64'])
        data = json.loads((self.arm64 / 'payload-info.json').read_text())
        data['files']['plugin.dll'] = module.file_hash(plugin)
        (self.arm64 / 'payload-info.json').write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'library architecture mismatch'):
            module.validate(self.arm64, 'arm64')

    def test_refuses_missing_runtime(self):
        (self.runtime / 'vc_redist.arm64.exe').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing arm64'):
            module.render(self.x64, self.arm64, self.root / 'dist', self.runtime)

    def test_refuses_stale_build(self):
        data = json.loads((self.x64 / 'payload-info.json').read_text())
        data['build'] += 1
        (self.x64 / 'payload-info.json').write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'version/build mismatch'):
            module.validate(self.x64, 'x64')


if __name__ == '__main__': unittest.main()
