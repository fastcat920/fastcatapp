#!/usr/bin/env python3
"""Record native Windows payloads and assemble one x64/ARM64 Inno installer."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MACHINES = {'x64': 0x8664, 'arm64': 0xaa64}


def version_info(root=ROOT):
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', (root / 'pubspec.yaml').read_text(), re.M)
    if not match:
        raise ValueError('pubspec version/build is missing')
    return match[1], int(match[2])


def config(root=ROOT):
    result = {}
    for line in (root / 'windows/packaging/exe/make_config.yaml').read_text().splitlines():
        match = re.match(r'^([a-z_]+):\s*(.+)$', line)
        if match:
            result[match[1]] = match[2].strip().strip('"\'')
    for key in ('app_id', 'executable_name', 'app_name', 'publisher', 'publisher_url'):
        if not result.get(key) or any(c in result[key] for c in '\r\n"'):
            raise ValueError(f'Invalid packaging setting: {key}')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+\.exe', result['executable_name'], re.I):
        raise ValueError('Executable name must be an ASCII file name')
    return result


def pe_machine(path):
    with path.open('rb') as stream:
        header = stream.read(64)
        if len(header) != 64 or header[:2] != b'MZ':
            raise ValueError(f'Invalid PE: {path.name}')
        stream.seek(struct.unpack_from('<I', header, 0x3c)[0])
        pe = stream.read(6)
        if pe[:4] != b'PE\0\0' or len(pe) != 6:
            raise ValueError(f'Invalid PE header: {path.name}')
        return struct.unpack_from('<H', pe, 4)[0]


def file_hash(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def payload_files(folder):
    for path in sorted(folder.rglob('*')):
        if path.is_symlink():
            raise ValueError('Payload must not contain symlinks')
        if path.is_file() and path.name != 'payload-info.json':
            yield path


def record(folder, architecture, commit, root=ROOT):
    if not folder.is_dir() or not commit:
        raise ValueError('Payload directory and build commit are required')
    settings = config(root)
    critical = {settings['executable_name'], 'flutter_windows.dll', 'fastcatCore.exe', 'fastcatHelperService.exe'}
    for name in critical:
        path = folder / name
        if not path.is_file() or pe_machine(path) != MACHINES[architecture]:
            raise ValueError(f'Missing or incorrect {architecture} binary: {name}')
    files = {}
    for path in payload_files(folder):
        if path.suffix.lower() in ('.exe', '.dll'):
            allowed = {MACHINES[architecture]}
            if architecture == 'arm64' and path.name not in critical:
                allowed.add(0xa641)  # ARM64EC redistributable libraries.
            if pe_machine(path) not in allowed:
                raise ValueError(f'Mixed architecture: {path.name}')
        files[path.relative_to(folder).as_posix()] = file_hash(path)
    version, build = version_info(root)
    receipt = dict(version=version, build=build, architecture=architecture, commit=commit, files=files)
    (folder / 'payload-info.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


def validate(folder, architecture, commit=None, root=ROOT):
    receipt = json.loads((folder / 'payload-info.json').read_text())
    version, build = version_info(root)
    if receipt.get('architecture') != architecture or receipt.get('version') != version or receipt.get('build') != build:
        raise ValueError('Payload architecture/version/build mismatch')
    if not receipt.get('commit') or (commit and receipt['commit'] != commit):
        raise ValueError('Payload build commit mismatch')
    actual = {p.relative_to(folder).as_posix(): file_hash(p) for p in payload_files(folder)}
    if not actual or receipt.get('files') != actual:
        raise ValueError('Payload file integrity mismatch')
    critical = [config(root)['executable_name'], 'flutter_windows.dll', 'fastcatCore.exe', 'fastcatHelperService.exe']
    if any(not (folder / n).is_file() or pe_machine(folder / n) != MACHINES[architecture] for n in critical):
        raise ValueError('Payload critical binary architecture mismatch')
    for path in payload_files(folder):
        if path.suffix.lower() in ('.exe', '.dll'):
            allowed = {MACHINES[architecture]}
            if architecture == 'arm64' and path.name not in critical:
                allowed.add(0xa641)
            if pe_machine(path) not in allowed:
                raise ValueError('Payload library architecture mismatch')
    return receipt


def render(x64, arm64, output, runtimes, root=ROOT, commit=None):
    left = validate(x64, 'x64', commit, root)
    right = validate(arm64, 'arm64', commit, root)
    if left['commit'] != right['commit']:
        raise ValueError('Cannot combine payloads from different commits')
    for arch in MACHINES:
        if not (runtimes / f'vc_redist.{arch}.exe').is_file():
            raise ValueError(f'Missing {arch} VC runtime')
    cfg = config(root)
    version, _ = version_info(root)
    output.mkdir(parents=True, exist_ok=True)
    installer_name = f'{Path(cfg["executable_name"]).stem}-Windows-{version}-Setup'
    text = (root / 'windows/packaging/exe/inno_setup_universal.iss').read_text()
    values = {
        'APP_ID': cfg['app_id'], 'APP_VERSION': version, 'DISPLAY_NAME': cfg.get('display_name', cfg['app_name']),
        'PUBLISHER_NAME': cfg['publisher'], 'PUBLISHER_URL': cfg['publisher_url'],
        'EXECUTABLE_NAME': cfg['executable_name'], 'INSTALL_DIR_NAME': Path(cfg['executable_name']).stem,
        'OUTPUT_BASE_FILENAME': installer_name, 'OUTPUT_DIR': str(output.resolve()),
        'SOURCE_X64': str(x64.resolve()), 'SOURCE_ARM64': str(arm64.resolve()),
        'RUNTIME_DIR': str(runtimes.resolve()),
        'SETUP_ICON_FILE': str((root / 'windows/runner/resources/app_icon.ico').resolve()),
        'CHINESE_ISL': str((root / 'windows/packaging/exe/ChineseSimplified.isl').resolve()),
    }
    for name, value in values.items():
        if any(c in value for c in '\r\n"'):
            raise ValueError(f'Unsafe installer value: {name}')
        text = text.replace('{{' + name + '}}', value)
    if '{{' in text or '{%' in text:
        raise ValueError('Unresolved installer template')
    script = output / 'windows-universal.iss'
    script.write_text(text, encoding='utf-8-sig')
    return script, output / f'{installer_name}.exe'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    capture = commands.add_parser('record')
    capture.add_argument('--directory', required=True, type=Path)
    capture.add_argument('--architecture', choices=MACHINES, required=True)
    capture.add_argument('--commit', default=os.environ.get('GITHUB_SHA'))
    assemble = commands.add_parser('package')
    assemble.add_argument('--x64', required=True, type=Path)
    assemble.add_argument('--arm64', required=True, type=Path)
    assemble.add_argument('--runtimes', required=True, type=Path)
    assemble.add_argument('--output', default=Path('dist'), type=Path)
    assemble.add_argument('--iscc', default='iscc')
    assemble.add_argument('--render-only', action='store_true')
    args = parser.parse_args()
    if args.command == 'record':
        record(args.directory, args.architecture, args.commit)
    else:
        script, installer = render(args.x64, args.arm64, args.output, args.runtimes, commit=os.environ.get('GITHUB_SHA'))
        if not args.render_only:
            subprocess.run([args.iscc, str(script)], check=True)
            if not installer.is_file():
                raise ValueError('Universal installer was not produced')
            script.unlink()


if __name__ == '__main__':
    main()
