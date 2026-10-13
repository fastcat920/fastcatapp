import importlib.util
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("release_policy", ROOT / "scripts/check_release_readiness.py")
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


class ReleasePolicyTest(unittest.TestCase):
    def test_test_builds_remain_available_without_signing_secrets(self):
        for platform in ("windows", "macos", "ios", "tvos", "linux", "android"):
            for channel in ("local", "test"):
                policy.check(platform, {"FASTCAT_BUILD_CHANNEL": channel})

    def test_unsigned_platforms_never_claim_release(self):
        for platform in ("windows", "macos", "ios", "tvos"):
            with self.assertRaises(ValueError):
                policy.check(platform, {"FASTCAT_BUILD_CHANNEL": "release"})

    def test_android_formal_release_needs_every_signing_secret(self):
        env = {"FASTCAT_BUILD_CHANNEL": "release", "KEYSTORE_BASE64": "test", "KEYSTORE_PASSWORD": "test",
               "KEY_ALIAS": "test", "KEY_PASSWORD": "test"}
        policy.check("android", env)
        for field in ("KEYSTORE_BASE64", "KEYSTORE_PASSWORD", "KEY_ALIAS", "KEY_PASSWORD"):
            with self.assertRaises(ValueError):
                policy.check("android", {**env, field: ""})

    def test_unknown_channel_fails_instead_of_bypassing_gate(self):
        with self.assertRaises(ValueError):
            policy.check("android", {"FASTCAT_BUILD_CHANNEL": "production"})

    def test_tvos_versions_share_pubspec_source(self):
        pubspec = (ROOT / "pubspec.yaml").read_text()
        version, number = re.search(r"^version: (\d+\.\d+\.\d+)\+(\d+)$", pubspec, re.M).groups()
        generated = (ROOT / "tvos/Version.xcconfig").read_text()
        self.assertIn(f"FASTCAT_APP_VERSION = {version}\n", generated)
        self.assertIn(f"FASTCAT_BUILD_NUMBER = {number}\n", generated)
        project = (ROOT / "tvos/FastCatTV.xcodeproj/project.pbxproj").read_text()
        self.assertEqual(project.count('MARKETING_VERSION = "$(FASTCAT_APP_VERSION)"'), 4)
        self.assertEqual(project.count('CURRENT_PROJECT_VERSION = "$(FASTCAT_BUILD_NUMBER)"'), 4)
        self.assertIn('include "Version.xcconfig"', (ROOT / "tvos/Build.xcconfig").read_text())

    def test_direct_flutter_builds_keep_provenance(self):
        for script in ("package_apk.sh", "package_ipa.sh"):
            source = (ROOT / "scripts" / script).read_text()
            self.assertIn("--dart-define=FASTCAT_BUILD_COMMIT=", source)
            self.assertIn("--dart-define=FASTCAT_BUILD_CHANNEL=", source)
        setup = (ROOT / "setup.dart").read_text()
        self.assertEqual(setup.count("'FASTCAT_BUILD_COMMIT',"), 2)
        self.assertEqual(setup.count("'FASTCAT_BUILD_CHANNEL',"), 2)

    def test_version_check_rejects_stale_or_missing_file(self):
        with tempfile.TemporaryDirectory(prefix="fastcat-version-test-") as directory:
            fixture = Path(directory)
            (fixture / "tvos").mkdir()
            (fixture / "pubspec.yaml").write_text("name: test\nversion: 4.2.1+19\n")
            script = str(ROOT / "scripts/sync_tvos_version.rb")
            command = ["ruby", "-r", script, "-e", "sync_tvos_version(ARGV[0], check: true)", directory]
            missing = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(missing.returncode, 0)
            generated = subprocess.run(["ruby", "-r", script, "-e", "sync_tvos_version(ARGV[0])", directory], capture_output=True, text=True)
            self.assertEqual(generated.returncode, 0, generated.stderr)
            current = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(current.returncode, 0, current.stderr)
            (fixture / "pubspec.yaml").write_text("name: test\nversion: 4.2.1+20\n")
            stale = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(stale.returncode, 0)
            self.assertIn("tvOS version is stale", stale.stderr)


if __name__ == "__main__":
    unittest.main()
