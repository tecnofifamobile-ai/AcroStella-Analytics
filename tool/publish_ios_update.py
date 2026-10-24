#!/usr/bin/env python3
"""Publish a validated unsigned IPA, both Flarestore feeds and the in-app feed.

Only the public installer repository is cloned. No signing keys are accessed.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile

from package_unsigned_ipa import PACKAGE, arm64_binary
from publish_android_update import public_url

REPOSITORY = 'tecnofifamobile-ai/AcroStella-Updates'
FEEDS = {'flarestore.json': 'com.acrostella.updates',
         'flarestore-latest.json': 'com.acrostella.updates.latest'}


def inspect_ipa(ipa):
    ipa = Path(ipa)
    with zipfile.ZipFile(ipa) as archive:
        names = archive.namelist()
        if sum(e.file_size for e in archive.infolist()) > 1024**3:
            raise ValueError('Application exceeds the packaging size limit')
        for name in names:
            path = PurePosixPath(name)
            if path.is_absolute() or '..' in path.parts or '\\' in name or path.parts[:2] != ('Payload', 'Runner.app'):
                raise ValueError('Expected safe Payload/Runner.app paths')
        if len(names) != len(set(names)) or len(names) > 20000:
            raise ValueError('Duplicate or excessive archive entries')
        if any(n.lower().endswith(('.p12', '.pfx', '.mobileprovision', '.keystore', '.jks')) for n in names):
            raise ValueError('Signing files must never be published')
        if any(n.startswith('Payload/Runner.app/_CodeSignature/') for n in names):
            raise ValueError('Expected Runner without a distribution signature')
        info = plistlib.loads(archive.read('Payload/Runner.app/Info.plist'))
        if info['CFBundleIdentifier'] != PACKAGE or 2 not in info.get('UIDeviceFamily', []):
            raise ValueError('Unexpected application identity or missing iPad support')
        if 'iPhoneOS' not in info.get('CFBundleSupportedPlatforms', []):
            raise ValueError('Expected a physical device build')
        version, code, minimum = info['CFBundleShortVersionString'], info['CFBundleVersion'], info['MinimumOSVersion']
        if not re.fullmatch(r'\d+\.\d+\.\d+', version) or not re.fullmatch(r'[1-9]\d*', code):
            raise ValueError('Invalid version/build')
        if not re.fullmatch(r'\d+\.\d+(?:\.\d+)?', minimum):
            raise ValueError('Invalid minimum OS')
        for name in ['Runner', 'Frameworks/Flutter.framework/Flutter', 'Frameworks/App.framework/App']:
            if not arm64_binary(archive, 'Payload/Runner.app/' + name):
                raise ValueError('Expected arm64 device binaries')
        if archive.testzip() is not None:
            raise ValueError('IPA CRC failure')
    with ipa.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    return {'version': version, 'code': int(code), 'min_os': minimum,
            'bytes': ipa.stat().st_size,
            'sha256': digest}


def catalogues(ipa, existing, notes, repository=REPOSITORY):
    metadata = inspect_ipa(ipa)
    if not notes.strip() or len(notes) > 4000:
        raise ValueError('Expected release notes of at most 4000 characters')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Invalid repository')
    version, code = metadata['version'], metadata['code']
    tag = f'ios-v{version}+{code}'
    asset = f'acrostella-analytics-{version}+{code}-unsigned.ipa'
    url = public_url(repository, tag, asset)
    date = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z')
    output = {}
    for filename, identifier in FEEDS.items():
        feed = json.loads(json.dumps(existing[filename]))
        if feed['identifier'] != identifier or feed['sourceURL'] != f'https://raw.githubusercontent.com/{repository}/main/{filename}':
            raise ValueError('Never change the identity/URL of an existing source')
        if len(feed['apps']) != 1 or feed['apps'][0]['bundleIdentifier'] != PACKAGE:
            raise ValueError('Unexpected source application')
        app = feed['apps'][0]
        previous = app['versions'][0]
        if code <= int(previous['buildVersion']) or tuple(map(int, version.split('.'))) < tuple(map(int, previous['version'].split('.'))):
            raise ValueError('Version/build must increase; never overwrite an installer')
        entry = {'version': version, 'buildVersion': str(code), 'date': date,
                 'localizedDescription': notes.strip(), 'downloadURL': url,
                 'size': metadata['bytes'], 'sha256': metadata['sha256'], 'minOSVersion': metadata['min_os']}
        app.update(versions=[entry], version=version, versionDate=date,
                   versionDescription=notes.strip(), downloadURL=url, size=metadata['bytes'],
                   subtitle=f'Versión {version} · build {code}', localizedDescription=notes.strip())
        # Do not require a client beta filter to see the current test installer.
        app.pop('isBeta', None)
        feed['subtitle'] = f'AcroStella {version} · build {code}'
        feed['news'] = [{'identifier': f'acrostella-{version}-{code}',
                         'title': f'AcroStella {version} disponible', 'caption': notes.strip(),
                         'date': date, 'appID': PACKAGE,
                         'url': f'https://github.com/{repository}/releases/tag/{tag}'}]
        output[filename] = feed
    output['acrostella-ios-update.json'] = {
        'schema': 1, 'platform': 'ios', 'package': PACKAGE, 'version_name': version,
        'version_code': code, 'min_os': metadata['min_os'], 'bytes': metadata['bytes'],
        'sha256': metadata['sha256'], 'download_url': url, 'notes': notes.strip()}
    return metadata, asset, tag, output


def command(*args, cwd=None):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    parser.add_argument('--notes-file', required=True, type=Path)
    args = parser.parse_args()
    ipa = args.ipa.resolve(strict=True)
    notes = args.notes_file.read_text()
    with tempfile.TemporaryDirectory(prefix='acrostella-ios-publish-') as temporary:
        checkout = Path(temporary) / 'installers'
        git = ('git', '-c', 'credential.helper=', '-c', 'credential.helper=!gh auth git-credential')
        command(*git, 'clone', '--depth', '1', f'https://github.com/{REPOSITORY}.git', str(checkout))
        existing = {name: json.loads((checkout / name).read_text()) for name in FEEDS}
        metadata, asset, tag, output = catalogues(ipa, existing, notes)
        if (checkout / asset).exists():
            parser.error('Never overwrite a published installer')
        shutil.copyfile(ipa, checkout / asset)
        checksum = asset + '.sha256'
        (checkout / checksum).write_text(f"{metadata['sha256']}  {asset}\n")
        for filename, feed in output.items():
            (checkout / filename).write_text(json.dumps(feed, ensure_ascii=False, indent=2) + '\n')
        readme = checkout / 'README.md'
        text = readme.read_text()
        previous = existing['flarestore.json']['apps'][0]['versions'][0]
        old = previous['version']
        text = text.replace(old, metadata['version']).replace(
            f"{metadata['version']}%2B{previous['buildVersion']}", f"{metadata['version']}%2B{metadata['code']}")
        text = text.replace(f"build {previous['buildVersion']}", f"build {metadata['code']}")
        readme.write_text(text)
        files = [asset, checksum, *output, 'README.md']
        command(*git, '-C', str(checkout), 'add', '--', *files)
        command(*git, '-C', str(checkout), '-c', 'user.name=AcroStella builds',
                '-c', 'user.email=builds@users.noreply.github.com', 'commit', '-m', f'Publicar {tag} y todos los canales iOS')
        commit = command(*git, '-C', str(checkout), 'rev-parse', 'HEAD')
        command(*git, '-C', str(checkout), 'tag', tag)
        command(*git, '-C', str(checkout), 'push', '--atomic', 'origin',
                'HEAD:refs/heads/main', f'refs/tags/{tag}')
        # Verify the exact public commit and full IPA before exposing the release.
        for filename in output:
            url = f'https://raw.githubusercontent.com/{REPOSITORY}/{commit}/{filename}'
            with urllib.request.urlopen(url, timeout=30) as response:
                if json.load(response) != output[filename]:
                    raise ValueError('Public source differs from prepared catalogue')
        with urllib.request.urlopen(public_url(REPOSITORY, tag, asset), timeout=60) as response:
            digest = hashlib.sha256()
            size = 0
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                size += len(chunk)
        if size != metadata['bytes'] or digest.hexdigest() != metadata['sha256']:
            raise ValueError('Public IPA verification failed')
        body = Path(temporary) / 'release.md'
        body.write_text(notes + '\n\n[Descargar IPA sin firma](' + public_url(REPOSITORY, tag, asset) +
                        ')\n\nSHA-256: `' + metadata['sha256'] + '`\n')
        command('gh', 'release', 'create', tag, '--repo', REPOSITORY,
                '--target', commit, '--title', f"AcroStella {metadata['version']} · iOS sin firma",
                '--notes-file', str(body), '--prerelease', '--latest=false')
        print(json.dumps({**metadata, 'public_commit': commit, 'tag': tag,
                          'download_url': public_url(REPOSITORY, tag, asset)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
