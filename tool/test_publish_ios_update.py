import copy
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
import zipfile

from publish_ios_update import FEEDS, PACKAGE, REPOSITORY, catalogues


class IosPublicationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.ipa = Path(self.directory.name) / 'app.ipa'
        self.feeds = {name: {'identifier': identifier,
            'sourceURL': f'https://raw.githubusercontent.com/{REPOSITORY}/main/{name}',
            'apps': [{'bundleIdentifier': PACKAGE, 'isBeta': True,
                'versions': [{'version': '0.5.1', 'buildVersion': '6'}]}]}
            for name, identifier in FEEDS.items()}
        self.fixture()

    def fixture(self, *, bundle=PACKAGE, code='7', extra=None):
        with zipfile.ZipFile(self.ipa, 'w') as archive:
            archive.writestr('Payload/Runner.app/Info.plist', plistlib.dumps({
                'CFBundleIdentifier': bundle, 'CFBundleShortVersionString': '0.5.2',
                'CFBundleVersion': code, 'MinimumOSVersion': '15.0',
                'CFBundleSupportedPlatforms': ['iPhoneOS'], 'UIDeviceFamily': [1, 2]}))
            for path in ['Runner', 'Frameworks/Flutter.framework/Flutter', 'Frameworks/App.framework/App']:
                archive.writestr('Payload/Runner.app/' + path, b'\xcf\xfa\xed\xfe\x0c\x00\x00\x01' + b'\0'*32)
            if extra:
                archive.writestr(extra, 'fixture')

    def test_all_catalogues_come_from_one_ipa_and_keep_source_identities(self):
        before = copy.deepcopy(self.feeds)
        meta, asset, tag, output = catalogues(self.ipa, self.feeds, 'Mejoras iOS')
        self.assertEqual(self.feeds, before)
        direct = output['acrostella-ios-update.json']
        self.assertEqual(direct['version_code'], 7)
        self.assertEqual(tag, 'ios-v0.5.2+7')
        self.assertEqual(direct['bytes'], self.ipa.stat().st_size)
        for name, identifier in FEEDS.items():
            feed = output[name]
            app = feed['apps'][0]
            self.assertEqual(feed['identifier'], identifier)
            self.assertEqual(feed['sourceURL'], before[name]['sourceURL'])
            self.assertEqual(app['version'], '0.5.2')
            self.assertEqual(len(app['versions']), 1)
            self.assertEqual(app['downloadURL'], direct['download_url'])
            self.assertEqual(app['versions'][0]['sha256'], meta['sha256'])
            self.assertNotIn('isBeta', app)
            self.assertEqual(feed['news'][0]['appID'], PACKAGE)

    def test_changed_source_identity_and_nonincreasing_build_are_rejected(self):
        self.feeds['flarestore.json']['identifier'] = 'changed'
        with self.assertRaises(ValueError): catalogues(self.ipa, self.feeds, 'Notes')
        self.feeds['flarestore.json']['identifier'] = FEEDS['flarestore.json']
        self.fixture(code='6')
        with self.assertRaises(ValueError): catalogues(self.ipa, self.feeds, 'Notes')

    def test_wrong_bundle_and_signing_files_are_rejected(self):
        self.fixture(bundle='wrong.bundle')
        with self.assertRaises(ValueError): catalogues(self.ipa, self.feeds, 'Notes')
        self.fixture(extra='Payload/Runner.app/test.mobileprovision')
        with self.assertRaises(ValueError): catalogues(self.ipa, self.feeds, 'Notes')

    def test_release_notes_and_repository_are_bounded(self):
        with self.assertRaises(ValueError): catalogues(self.ipa, self.feeds, 'x'*4001)
        with self.assertRaises(ValueError): catalogues(self.ipa, self.feeds, 'Notes', '../repo')
