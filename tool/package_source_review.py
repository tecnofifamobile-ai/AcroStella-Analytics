#!/usr/bin/env python3
"""Prepare a LOCAL source/licence review bundle. This script never publishes it.

Only tracked build/source/test files are selected; conversation context,
.git, credentials, recordings, local signing keys and binaries are excluded.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TREES = {'lib', 'test', 'android', 'ios', 'packages', 'third_party', 'tool', '.github'}
FILES = {'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml', '.metadata', '.gitignore', '.gitattributes'}
FORBIDDEN = {'.p12', '.pfx', '.mobileprovision', '.provisionprofile', '.pem', '.key', '.jks', '.keystore', '.mp4', '.mov', '.m4v', '.acrostella'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    manifest = []
    args.destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.destination, 'w', compression=zipfile.ZIP_DEFLATED) as output:
        for relative in sorted(filter(None, tracked)):
            path = Path(relative)
            if path.parts[0] not in TREES and relative not in FILES:
                continue
            if path.suffix.lower() in FORBIDDEN or path.name in {'key.properties', 'local.properties'} or '.env' in path.name:
                raise ValueError('Excluded sensitive file in tracked source: '+relative)
            file = ROOT/path
            if file.is_symlink():
                raise ValueError('Source review requires regular files: '+relative)
            content = file.read_bytes()
            output.writestr('AcroStella-Analytics/'+relative, content)
            manifest.append({'path':relative, 'bytes':len(content), 'sha256':hashlib.sha256(content).hexdigest()})
        output.writestr('AcroStella-Analytics/PROPOSED-LICENSE.txt', (ROOT/'packages/acro_workspace/LICENSE').read_bytes())
        output.writestr('AcroStella-Analytics/BUILD-AND-NOTICES.md', (ROOT/'docs/remote-workspace.md').read_bytes())
        output.writestr('SOURCE-MANIFEST.json', json.dumps({
            'schema':1, 'revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'publication_authorized':False, 'files':manifest,
            'notice':'Local review only. Public distribution of this combined app requires source and compatible licence authorization. Native dependency source archives are listed separately in upstream.json; SDK and other dependencies are pinned by lockfiles.'
        }, indent=2))
    digest=hashlib.file_digest(args.destination.open('rb'),'sha256').hexdigest()
    Path(str(args.destination)+'.sha256').write_text(digest+'  '+args.destination.name+'\n')
    print(json.dumps({'archive':str(args.destination), 'files':len(manifest), 'bytes':args.destination.stat().st_size, 'sha256':digest}))

if __name__=='__main__':
    main()
