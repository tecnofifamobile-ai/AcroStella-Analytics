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

def media_sources(metadata,cache,spm):
    """Build exact redistributable sources rather than opaque upstream archives."""
    jobs=str(min(8,os.cpu_count() or 4))
    sdk=subprocess.check_output(['xcrun','--sdk','iphoneos','--show-sdk-path'],text=True).strip()
    clang=subprocess.check_output(['xcrun','--sdk','iphoneos','-f','clang'],text=True).strip()
    for entry in metadata['media_sources']:
        name=entry['name']
        archive=cache/(name+'-source.tar.gz')
        fetch(entry['url'],archive,entry['sha256'])
        source=cache/(name+'-source')
        if not source.exists():
            unpack=cache/(name+'-unpack');unpack.mkdir(exist_ok=True)
            with tarfile.open(archive) as content:content.extractall(unpack,filter='data')
            next(unpack.iterdir()).rename(source)
            unpack.rmdir()
        prefix=cache/(name+'-device')
        stamp=prefix/'acrostella-source-build.json'
        if not stamp.exists():
            log=cache/(name+'-build.log')
            environment=dict(os.environ,SDKROOT=sdk)
            if name=='FFmpeg':
                commands=[['./configure','--prefix='+str(prefix),'--target-os=darwin','--arch=arm64',
                    '--cc='+clang,'--enable-cross-compile','--disable-all','--disable-autodetect',
                    '--disable-x86asm','--enable-avcodec','--enable-avformat','--enable-muxer=flv',
                    '--enable-decoder=av1','--disable-shared','--enable-static',
                    '--extra-cflags=-miphoneos-version-min=15.0 -arch arm64 --target=arm64-apple-ios15.0 -isysroot '+sdk,
                    '--extra-ldflags=-miphoneos-version-min=15.0 -arch arm64 --target=arm64-apple-ios15.0 -isysroot '+sdk],
                    ['make','-j',jobs],['make','install']]
            else:
                build=cache/(name+'-cmake')
                options=['-DSDL_SHARED=OFF','-DSDL_STATIC=ON','-DSDL_TEST=OFF'] if name=='SDL2' else [
                    '-DBUILD_SHARED_LIBS=OFF','-DOPUS_BUILD_TESTING=OFF','-DOPUS_BUILD_PROGRAMS=OFF']
                commands=[['cmake','-S',str(source),'-B',str(build),'-DCMAKE_BUILD_TYPE=Release',
                    '-DCMAKE_SYSTEM_NAME=iOS','-DCMAKE_OSX_SYSROOT=iphoneos',
                    '-DCMAKE_OSX_ARCHITECTURES=arm64','-DCMAKE_OSX_DEPLOYMENT_TARGET=15.0',
                    '-DCMAKE_INSTALL_PREFIX='+str(prefix),*options],
                    ['cmake','--build',str(build),'--parallel',jobs],['cmake','--install',str(build)]]
            with log.open('w') as output:
                for command in commands:
                    result=subprocess.run(command,cwd=source,env=environment,stdout=output,stderr=subprocess.STDOUT)
                    if result.returncode:
                        output.flush();print('\n'.join(log.read_text().splitlines()[-100:]))
                        raise RuntimeError(name+' source build failed')
            stamp.write_text(json.dumps(entry,indent=2))
        headers=spm/'NativeHeaders'/name
        if headers.exists():shutil.rmtree(headers)
        # Opus includes are nested as <opus/opus.h> by CMake install.
        shutil.copytree(prefix/'include',headers)
        if name=='FFmpeg':
            # The upstream renderer also uses FFmpeg's internal AV1 CBS types.
            # Use the exact headers from the source compiled above.
            for private in (source/'libavcodec').glob('*.h'):
                shutil.copyfile(private,headers/'libavcodec'/private.name)
        for library in (['avcodec','avformat','avutil'] if name=='FFmpeg' else [name]):
            compiled=prefix/'lib'/('lib'+library+'.a')
            destination=spm/'Frameworks'/(library+'.xcframework')
            if destination.exists():shutil.rmtree(destination)
            subprocess.run(['xcodebuild','-create-xcframework','-library',str(compiled),'-output',str(destination)],check=True)
        print(name+' '+entry['version']+' built from pinned source.')

def main():
    if platform.system()!='Darwin':raise SystemExit('iPadOS native preparation requires macOS/Xcode')
    package=ROOT/'packages/acro_workspace'
    metadata=json.loads((package/'upstream.json').read_text())
    spm=package/'ios/acro_workspace'
    output=spm/'Frameworks';output.mkdir(exist_ok=True)
    cache=ROOT/'.dart_tool/workspace-native';cache.mkdir(parents=True,exist_ok=True)
    openssl(metadata,cache,spm)
    media_sources(metadata,cache,spm)
    print('Pinned iOS native dependencies prepared; no application codesigning performed.')

if __name__=='__main__':main()
