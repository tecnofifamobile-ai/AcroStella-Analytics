#!/usr/bin/env python3
"""Publish only a verified APK and its manifest, never the private source tree.

Run from the private project with the SAME Android signing key each time:
  flutter build apk --release
  python3 tool/publish_android_update.py build/app/outputs/flutter-apk/app-release.apk --notes-file /tmp/release-notes.txt
Uses the existing gh authentication. No credentials belong in the APK or manifest.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import urllib.parse
import urllib.request

PACKAGE = "com.acrostella.acrostella_analytics"
DEFAULT_REPO = "tecnofifamobile-ai/AcroStella-Updates"


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def public_url(repo, tag, name):
    return 'https://raw.githubusercontent.com/' + '/'.join(
        urllib.parse.quote(segment, safe='')
        for segment in [*repo.split('/'), 'refs', 'tags', tag, name])


def fetch_public(url, destination):
    with urllib.request.urlopen(url, timeout=60) as response, destination.open('wb') as output:
        shutil.copyfileobj(response, output)


def push_installers(repo, branch, folder, asset, tag):
    # Clone ONLY the public installer repository. Never add the private tree.
    checkout = folder / 'public-installers'
    git = ('git', '-c', 'credential.helper=', '-c', 'credential.helper=!gh auth git-credential')
    command(*git, 'clone', '--depth', '1', '--branch', branch,
            f'https://github.com/{repo}.git', str(checkout))
    if (checkout / asset).exists():
        raise RuntimeError('Never overwrite an existing installer')
    for name in [asset, 'acrostella-update.json']:
        shutil.copyfile(folder / name, checkout / name)
    command(*git, '-C', str(checkout), 'add', '--', asset, 'acrostella-update.json')
    command(*git, '-C', str(checkout), '-c', 'user.name=AcroStella builds',
            '-c', 'user.email=builds@users.noreply.github.com', 'commit', '-m', f'Publicar {tag}')
    command(*git, '-C', str(checkout), 'tag', tag)
    command(*git, '-C', str(checkout), 'push', '--atomic', 'origin',
            f'HEAD:refs/heads/{branch}', f'refs/tags/{tag}')
    return command(*git, '-C', str(checkout), 'rev-parse', 'HEAD')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--notes-file", required=True, type=Path)
    parser.add_argument("--repo", default=DEFAULT_REPO)
    parser.add_argument('--git-assets', action='store_true',
                        help='Store installers in public Git and pin downloads to a release tag (APK under 100 MiB)')
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repo):
        parser.error("Invalid public repository")
    repo = json.loads(command("gh", "api", f"repos/{args.repo}"))
    if repo["private"]:
        parser.error("The installer repository must be public; do not publish private source repositories")
    apk = args.apk.resolve(strict=True)
    sdk = Path(os.environ["ANDROID_HOME"])
    tools = sdk / "build-tools/36.0.0"
    command(str(tools / "apksigner"), "verify", str(apk))
    certificates = command(str(tools / "apksigner"), "verify", "--print-certs", str(apk))
    signers = re.findall(r"^Signer #\d+ certificate SHA-256 digest: ([a-f0-9]{64})$", certificates, re.M)
    if len(signers) != 1:
        parser.error("Exactly one stable APK signing key is required")
    metadata = command(str(tools / "aapt"), "dump", "badging", str(apk))
    package = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", metadata, re.M)
    minimum = re.search(r"^sdkVersion:'(\d+)'", metadata, re.M)
    if not package or not minimum or package[1] != PACKAGE:
        parser.error("APK identity does not match AcroStella")
    code, version = int(package[2]), package[3]
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?", version):
        parser.error("Invalid APK version")
    if args.git_assets and not re.fullmatch(r'\d+\.\d+\.\d+', version):
        parser.error('Git-backed distribution currently requires a stable numeric version')
    notes = args.notes_file.read_text()
    if len(notes) > 4000 or not notes.strip():
        parser.error("Release notes must contain 1–4000 characters")
    size = apk.stat().st_size
    if not 0 < size <= 350 * 1024 * 1024:
        parser.error("Invalid APK size")
    digest = hashlib.file_digest(apk.open("rb"), "sha256").hexdigest()
    tag = f"v{version}+{code}"
    pages = json.loads(command("gh", "api", '--paginate', '--slurp', f"repos/{args.repo}/releases?per_page=100"))
    releases = [release for page in pages for release in page]
    existing_release = next((r for r in releases if r['tag_name'] == tag), None)
    resumable = args.git_assets and existing_release and existing_release['draft'] and not existing_release['assets']
    if existing_release and not resumable:
        parser.error("This release already exists; never replace a published APK. Increment the version code.")
    # Increasing codes are required independently of the human-facing version.
    for release in releases:
        match = re.search(r"\+(\d+)$", release["tag_name"])
        if not release["draft"] and match and int(match[1]) >= code:
            parser.error("Version code must be newer than every published release")
    asset = f"acrostella-analytics-{version}+{code}.apk"
    manifest = {"schema": 1, "package": PACKAGE, "version_code": code,
                "version_name": version, "min_sdk": int(minimum[1]), "bytes": size,
                "sha256": digest, "apk_asset": asset, "notes": notes.strip()}
    manifest["signer_sha256"] = signers[0]
    with tempfile.TemporaryDirectory(prefix="acrostella-publish-") as temporary:
        folder = Path(temporary)
        payload = folder / "payload.json"
        previous = next((release for release in releases if not release["draft"] and not release["prerelease"]), None)
        if previous:
            prior = folder / "previous"
            prior.mkdir()
            if previous['assets']:
                command("gh", "release", "download", previous["tag_name"], "--repo", args.repo,
                        "--pattern", "acrostella-update.json", "--dir", str(prior))
            else:
                fetch_public(public_url(args.repo, previous['tag_name'], 'acrostella-update.json'),
                             prior / 'acrostella-update.json')
            if json.loads((prior / "acrostella-update.json").read_text()).get("signer_sha256") != signers[0]:
                parser.error("Signing key changed. Restore the original Android key; never publish an incompatible update.")
        # Empty repositories cannot host a release tag. Only initialize a public
        # downloads README; never clone/push/copy the private project here.
        head = subprocess.run(["gh", "api", f"repos/{args.repo}/commits/{repo['default_branch']}"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if head.returncode:
            readme = "# AcroStella Analytics\n\nInstaladores Android y manifiestos de actualización. El código fuente y los vídeos no se publican aquí.\n\nDescarga el APK de la última versión en Releases. Las siguientes actualizaciones se ofrecen dentro de la app.\n"
            payload.write_text(json.dumps({"message": "Preparar distribución de instaladores",
                "content": base64.b64encode(readme.encode()).decode()}))
            command("gh", "api", "--method", "PUT", f"repos/{args.repo}/contents/README.md", "--input", str(payload))
        (folder / "acrostella-update.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        # Copy exactly one inspected binary, not a directory or Git checkout.
        shutil.copyfile(apk, folder / asset)
        if not existing_release:
            command("gh", "release", "create", tag, "--repo", args.repo, "--draft",
                    "--title", f"AcroStella Analytics {version}", "--notes-file", str(args.notes_file))
        if args.git_assets:
            if size >= 100 * 1024 * 1024:
                parser.error('Git-backed APK must be under 100 MiB; use release assets for larger builds')
            commit = push_installers(args.repo, repo['default_branch'], folder, asset, tag)
            fetched = folder / 'downloaded'
            fetched.mkdir()
            fetch_public(public_url(args.repo, tag, asset), fetched / asset)
            fetch_public(public_url(args.repo, tag, 'acrostella-update.json'), fetched / 'acrostella-update.json')
            if hashlib.file_digest((fetched / asset).open('rb'), 'sha256').hexdigest() != digest:
                raise RuntimeError('Public APK verification failed; release remains a draft')
            if json.loads((fetched / 'acrostella-update.json').read_text()) != manifest:
                raise RuntimeError('Public manifest verification failed; release remains a draft')
            public_notes = folder / 'release-notes.md'
            public_notes.write_text(notes.strip() + '\n\n[Descargar APK (' +
                f'{size / 1000000:.1f} MB)]({public_url(args.repo, tag, asset)})\n')
            command('gh', 'release', 'edit', tag, '--repo', args.repo, '--target', commit,
                    '--notes-file', str(public_notes), '--draft=false', '--latest')
            print(public_url(args.repo, tag, asset))
            return
        command("gh", "release", "upload", tag, str(folder / asset),
                str(folder / "acrostella-update.json"), "--repo", args.repo)
        # Verify both uploads while still a draft. A failed upload stays a draft.
        fetched = folder / "downloaded"
        fetched.mkdir()
        command("gh", "release", "download", tag, "--repo", args.repo, "--dir", str(fetched))
        if hashlib.file_digest((fetched / asset).open("rb"), "sha256").hexdigest() != digest:
            raise RuntimeError("Round-trip APK verification failed; release remains a draft")
        if json.loads((fetched / "acrostella-update.json").read_text()) != manifest:
            raise RuntimeError("Round-trip manifest verification failed; release remains a draft")
        command("gh", "release", "edit", tag, "--repo", args.repo, "--draft=false", "--latest")
    print(f"https://github.com/{args.repo}/releases/tag/{tag}")


if __name__ == "__main__":
    main()
