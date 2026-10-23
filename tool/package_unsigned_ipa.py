#!/usr/bin/env python3
"""Package a macOS-built device .app ZIP for signing on the user's device.

This does not compile, sign, or prove installation. No certificates are read.
Usage: python3 tool/package_unsigned_ipa.py APP_ZIP OUTPUT_DIRECTORY
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import stat
import struct
import zipfile

PACKAGE = 'com.acrostella.acrostellaAnalytics'


def arm64_binary(archive, name):
    with archive.open(name) as stream:
        header = stream.read(8)
        if len(header) != 8:
            return False
        if header[:4] == b'\xcf\xfa\xed\xfe':
            return struct.unpack('<I', header[4:])[0] == 0x0100000C
        if header[:4] not in [b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf']:
            return False
        count = struct.unpack('>I', header[4:])[0]
        if not 1 <= count <= 16:
            return False
        wide = header[:4] == b'\xca\xfe\xba\xbf'
        stride = 32 if wide else 20
        table = stream.read(count * stride)
        if len(table) != count * stride:
            return False
        for index in range(count):
            entry = table[index * stride:(index + 1) * stride]
            cpu, _, offset, size, *_ = struct.unpack('>IIQQII' if wide else '>IIIII', entry)
            if cpu != 0x0100000C or offset < 8 + len(table) or size < 8 or offset + size > archive.getinfo(name).file_size:
                return False
            stream.seek(offset)
            if stream.read(8) != b'\xcf\xfa\xed\xfe\x0c\x00\x00\x01':
                return False
        return True


def package(source, output):
    source, output = Path(source), Path(output)
    with zipfile.ZipFile(source) as archive:
        entries = archive.infolist()
        names = [entry.filename for entry in entries]
        if len(names) != len(set(names)) or len(names) > 20000:
            raise ValueError('Duplicate or excessive archive entries')
        if sum(entry.file_size for entry in entries) > 1024 ** 3:
            raise ValueError('Application exceeds the packaging size limit')
        for name in names:
            path = PurePosixPath(name)
            if path.is_absolute() or '..' in path.parts or '\\' in name or not path.parts or path.parts[0] != 'Runner.app':
                raise ValueError('Expected only safe Runner.app paths')
            if name.lower().endswith(('.p12', '.mobileprovision', '.pfx', '.jks', '.keystore')):
                raise ValueError('Signing material must not be included')
        info = plistlib.loads(archive.read('Runner.app/Info.plist'))
        version, code = info['CFBundleShortVersionString'], info['CFBundleVersion']
        if info['CFBundleIdentifier'] != PACKAGE or info['CFBundleExecutable'] != 'Runner':
            raise ValueError('Unexpected application identity')
        if not re.fullmatch(r'\d+\.\d+\.\d+', version) or not re.fullmatch(r'\d+', code):
            raise ValueError('Invalid version')
        if 'iPhoneOS' not in info.get('CFBundleSupportedPlatforms', []) or 2 not in info.get('UIDeviceFamily', []):
            raise ValueError('Expected a device build supporting iPad')
        if not info.get('NSCameraUsageDescription'):
            raise ValueError('Missing camera permission description')
        for binary in ['Runner.app/Runner', 'Runner.app/Frameworks/Flutter.framework/Flutter', 'Runner.app/Frameworks/App.framework/App']:
            if not arm64_binary(archive, binary):
                raise ValueError('Expected arm64 Mach-O device binaries')
        if not archive.getinfo('Runner.app/Runner').external_attr >> 16 & stat.S_IXUSR:
            raise ValueError('Runner executable permission is missing')
        if archive.testzip() is not None:
            raise ValueError('Input archive CRC failure')
        output.mkdir(parents=True, exist_ok=True)
        destination = output / f'acrostella-analytics-{version}+{code}-unsigned.ipa'
        if destination.exists():
            raise FileExistsError('Never silently replace an existing IPA')
        pending = destination.with_suffix('.ipa.partial')
        try:
            with zipfile.ZipFile(pending, 'w', compression=zipfile.ZIP_DEFLATED) as ipa:
                for entry in entries:
                    cloned = copy.copy(entry)
                    cloned.filename = f'Payload/{entry.filename}'
                    # Keep the original Unix modes and symlink payloads.
                    cloned.compress_type = zipfile.ZIP_DEFLATED
                    ipa.writestr(cloned, archive.read(entry.filename))
            with zipfile.ZipFile(pending) as ipa:
                if ipa.testzip() is not None:
                    raise ValueError('Output archive CRC failure')
                if plistlib.loads(ipa.read('Payload/Runner.app/Info.plist')) != info:
                    raise ValueError('Application metadata changed during packaging')
            pending.rename(destination)
        finally:
            pending.unlink(missing_ok=True)
    with destination.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    destination.with_suffix('.ipa.sha256').write_text(f'{digest}  {destination.name}\n')
    return {'path': str(destination), 'bytes': destination.stat().st_size,
            'sha256': digest, 'bundle_id': PACKAGE, 'version': version,
            'build': code, 'signed': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app_zip', type=Path)
    parser.add_argument('output_directory', type=Path)
    args = parser.parse_args()
    print(json.dumps(package(args.app_zip, args.output_directory), ensure_ascii=False))
