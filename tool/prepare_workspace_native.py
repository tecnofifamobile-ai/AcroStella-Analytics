#!/usr/bin/env python3
"""Pinned iOS dependencies, including OpenSSL built from source. No signing keys."""
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import urllib.request

ROOT=Path(__file__).resolve().parents[1]

def fetch(url,destination,digest):
    if destination.exists() and hashlib.file_digest(destination.open('rb'),'sha256').hexdigest()==digest:
        return
    partial=destination.with_suffix('.part')
    with urllib.request.urlopen(url,timeout=120) as response,partial.open('wb') as output:
        shutil.copyfileobj(response,output)
    if hashlib.file_digest(partial.open('rb'),'sha256').hexdigest()!=digest:
        partial.unlink()
        raise ValueError('Native dependency hash mismatch')
    partial.replace(destination)

def openssl(metadata,cache,spm):
    description=metadata['openssl_source']
    archive=cache/'openssl-source.tar.gz'
    fetch(description['url'],archive,description['sha256'])
    source=cache/f"openssl-{description['commit']}"
    prefix=cache/'openssl-device'
    combined=cache/'libAcroTLS.a'
    if not combined.exists():
        if not source.exists():
            with tarfile.open(archive) as content:content.extractall(cache,filter='data')
        log=cache/'openssl-build.log'
        environment=dict(os.environ)
        # The ios64-xcrun target chooses the actual iPhoneOS compiler/SDK.
        environment.pop('CC',None)
        commands=[['perl','Configure','ios64-xcrun','no-shared','no-tests','no-module',
                   '-mios-version-min=15.0','--prefix='+str(prefix),'--openssldir='+str(prefix/'ssl')],
                  ['make','-j',str(min(8,os.cpu_count() or 4))],['make','install_sw']]
        with log.open('w') as output:
            for command in commands:
                result=subprocess.run(command,cwd=source,env=environment,stdout=output,stderr=subprocess.STDOUT)
                if result.returncode:
                    output.flush()
                    print('\n'.join(log.read_text().splitlines()[-100:]))
                    raise RuntimeError('OpenSSL source build failed')
        crypto=next(prefix.glob('lib*/libcrypto.a'))
        ssl=next(prefix.glob('lib*/libssl.a'))
        subprocess.run(['xcrun','libtool','-static','-o',str(combined),str(ssl),str(crypto)],check=True)
    headers=spm/'NativeHeaders/OpenSSL'
    if headers.exists():shutil.rmtree(headers)
    shutil.copytree(prefix/'include',headers)
    destination=spm/'Frameworks/AcroTLS.xcframework'
    if not destination.exists():
        subprocess.run(['xcodebuild','-create-xcframework','-library',str(combined),'-output',str(destination)],check=True)
    print('OpenSSL '+description['version']+' compiled from pinned source for iPhoneOS arm64.')

def main():
    if platform.system()!='Darwin':raise SystemExit('iPadOS native preparation requires macOS/Xcode')
    package=ROOT/'packages/acro_workspace'
    metadata=json.loads((package/'upstream.json').read_text())
    spm=package/'ios/acro_workspace'
    output=spm/'Frameworks';output.mkdir(exist_ok=True)
    cache=ROOT/'.dart_tool/workspace-native';cache.mkdir(parents=True,exist_ok=True)
    openssl(metadata,cache,spm)
    for entry in metadata['native_archives']:
        archive=cache/f"lib{entry['name']}.a"
        url=f"https://raw.githubusercontent.com/moonlight-stream/moonlight-ios/{metadata['moonlight_ios_commit']}/{entry['path']}"
        fetch(url,archive,entry['sha256'])
        destination=output/f"{entry['name']}.xcframework"
        if not destination.exists():
            # Headers live once in NativeHeaders; exporting duplicate FFmpeg
            # headers from three archives causes Xcode multiple-output errors.
            subprocess.run(['xcodebuild','-create-xcframework','-library',str(archive),'-output',str(destination)],check=True)
    print('Pinned iOS native dependencies prepared; no application codesigning performed.')

if __name__=='__main__':main()
