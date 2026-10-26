#!/usr/bin/env python3
"""Prepare pinned upstream device-only archives on macOS; no signing keys."""
import hashlib,json,pathlib,platform,shutil,subprocess,urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 if platform.system()!='Darwin':raise SystemExit('iPadOS native preparation requires macOS/Xcode')
 package=ROOT/'packages/acro_workspace';metadata=json.loads((package/'upstream.json').read_text())
 spm=package/'ios/acro_workspace';output=spm/'Frameworks';output.mkdir(exist_ok=True)
 cache=ROOT/'.dart_tool/workspace-native';cache.mkdir(parents=True,exist_ok=True)
 for entry in metadata['native_archives']:
  archive=cache/f"lib{entry['name']}.a"
  if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest()!=entry['sha256']:
   url=f"https://raw.githubusercontent.com/moonlight-stream/moonlight-ios/{metadata['moonlight_ios_commit']}/{entry['path']}"
   part=archive.with_suffix('.part')
   with urllib.request.urlopen(url,timeout=90) as response,part.open('wb') as target:shutil.copyfileobj(response,target)
   if hashlib.sha256(part.read_bytes()).hexdigest()!=entry['sha256']:raise ValueError('Native archive hash mismatch')
   part.replace(archive)
  destination=output/f"{entry['name']}.xcframework"
  if not destination.exists():
   subprocess.run(['xcodebuild','-create-xcframework','-library',str(archive),'-output',str(destination)],check=True)
 print('Pinned iOS native archives prepared; no codesigning performed.')
if __name__=='__main__':main()
