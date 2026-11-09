#!/usr/bin/env python3
"""Validate packaged privacy manifests and localized permission purposes.
Usage: python3 scripts/check_ios_privacy.py path/to/Runner.app-or.xcarchive
This is a local artifact check, not App Store Connect validation.
"""
import json
from pathlib import Path
import subprocess
import sys


def read_plist(path):
    # Xcode may encode InfoPlist.strings as binary or OpenStep property lists.
    result = subprocess.run(
        ['plutil', '-convert', 'json', '-o', '-', str(path)],
        check=True, capture_output=True,
    )
    return json.loads(result.stdout)


def check(path):
    app = Path(path)
    if app.suffix == '.xcarchive':
        apps = list((app / 'Products/Applications').glob('*.app'))
        if len(apps) != 1:
            raise ValueError('Expected exactly one application in archive')
        app = apps[0]
    requirements = {
        'NSPrivacyAccessedAPICategoryFileTimestamp': 'C617.1',
        'NSPrivacyAccessedAPICategorySystemBootTime': '35F9.1',
    }
    for bundle in [app, app / 'PlugIns/PacketTunnel.appex']:
        manifest = read_plist(bundle / 'PrivacyInfo.xcprivacy')
        declarations = {
            item['NSPrivacyAccessedAPIType']: item['NSPrivacyAccessedAPITypeReasons']
            for item in manifest['NSPrivacyAccessedAPITypes']
        }
        for category, reason in requirements.items():
            if reason not in declarations.get(category, []):
                raise ValueError(f'{bundle.name}: missing {category} / {reason}')
        if bundle == app and 'CA92.1' not in declarations.get(
            'NSPrivacyAccessedAPICategoryUserDefaults', []
        ):
            raise ValueError('Main app UserDefaults declaration was lost')
        print(f'{bundle.name}: required reason declarations OK')
    purposes = ['NSCameraUsageDescription', 'NSPhotoLibraryUsageDescription']
    for locale in ['en', 'zh-Hans', 'zh-Hant']:
        strings = read_plist(app / f'{locale}.lproj/InfoPlist.strings')
        for key in purposes:
            if not isinstance(strings.get(key), str) or not strings[key].strip():
                raise ValueError(f'{locale}: missing {key}')
        if locale == 'en' and any(
            '\u4e00' <= char <= '\u9fff'
            for key in purposes for char in strings[key]
        ):
            raise ValueError('English permission purposes contain Chinese fallback')
        print(f'{locale}: camera and photo purposes OK')
    info = read_plist(app / 'Info.plist')
    english = read_plist(app / 'en.lproj/InfoPlist.strings')
    for key in purposes:
        if info.get(key) != english[key]:
            raise ValueError(f'English fallback differs for {key}')
    print('English fallback OK; local artifact checks passed.')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    try:
        check(sys.argv[1])
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        raise SystemExit(f'Privacy validation failed: {error}')
