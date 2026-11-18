#!/usr/bin/env python3
"""Generate integrity metadata alongside installers. Never signs/publishes OSS."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import quote

TYPES = {'.apk': 'apk', '.exe': 'exe', '.dmg': 'dmg', '.deb': 'deb', '.rpm': 'rpm', '.appimage': 'appimage'}


def describe(path, base_url=''):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    name = path.name.lower()
    architecture = next((key for aliases, key in [
        (['arm64-v8a', 'arm64', 'aarch64'], 'arm64'),
        (['armeabi-v7a', 'armv7', '-arm.'], 'arm'),
        (['x86_64', 'amd64', 'x64'], 'x64')]
        if any(alias in name for alias in aliases)), 'universal')
    return dict(file=path.name, architecture=architecture,
                package_type=TYPES[path.suffix.lower()], size=path.stat().st_size,
                sha256=digest.hexdigest(),
                url=f'{base_url.rstrip("/")}/{quote(path.name)}' if base_url else '')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', default='dist')
    parser.add_argument('--base-url', default='', help='HTTPS installer directory (optional)')
    parser.add_argument('--architecture', choices=['arm', 'arm64', 'x64', 'universal'])
    args = parser.parse_args()
    if args.base_url and not args.base_url.startswith('https://'):
        parser.error('--base-url must use HTTPS')
    root = Path(args.directory)
    files = sorted(p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in TYPES)
    if not files:
        parser.error('No supported installers found')
    # Records instead of an architecture-keyed map preserve deb/rpm/AppImage choices.
    records = [describe(path, args.base_url) for path in files]
    if args.architecture:
        for record in records:
            record['architecture'] = args.architecture
    match = re.search(r'^version:\s*(\S+)', Path('pubspec.yaml').read_text(), re.M)
    version, _, build = match.group(1).partition('+') if match else ('', '', '')
    (root / 'update-manifest.json').write_text(
        json.dumps(dict(version=version, build=int(build) if build.isdigit() else None, artifacts=records), indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(f'Generated integrity metadata for {len(records)} installers.')


if __name__ == '__main__':
    main()
