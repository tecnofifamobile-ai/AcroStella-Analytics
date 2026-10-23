import plistlib
from pathlib import Path
import tempfile
import struct
import unittest
import zipfile

from package_unsigned_ipa import PACKAGE, package


class PackagingTests(unittest.TestCase):
    def fixture(self, path, *, platform='iPhoneOS', extra=None, fat=False):
        binary = b'\xcf\xfa\xed\xfe\x0c\x00\x00\x01' + b'\0' * 32
        with zipfile.ZipFile(path, 'w') as archive:
            archive.writestr('Runner.app/Info.plist', plistlib.dumps({
                'CFBundleIdentifier': PACKAGE, 'CFBundleExecutable': 'Runner',
                'CFBundleShortVersionString': '0.4.0', 'CFBundleVersion': '4',
                'CFBundleSupportedPlatforms': [platform], 'UIDeviceFamily': [1, 2],
                'NSCameraUsageDescription': 'Camera for training',
            }))
            for name in ['Runner.app/Runner', 'Runner.app/Frameworks/Flutter.framework/Flutter', 'Runner.app/Frameworks/App.framework/App']:
                entry = zipfile.ZipInfo(name)
                entry.create_system = 3
                entry.external_attr = 0o100755 << 16
                payload = binary
                if fat and name.endswith('App.framework/App'):
                    prefix = b'\xca\xfe\xba\xbe' + struct.pack('>I', 1) + struct.pack('>IIIII', 0x0100000C, 0, 4096, len(binary), 12)
                    payload = prefix.ljust(4096, b'\0') + binary
                archive.writestr(entry, payload)
            link = zipfile.ZipInfo('Runner.app/ResourcesLink')
            link.create_system = 3
            link.external_attr = 0o120777 << 16
            archive.writestr(link, 'Frameworks')
            if extra:
                archive.writestr(extra, b'invalid')

    def test_payload_preserves_binaries_permissions_and_symlinks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'app.zip'
            self.fixture(source)
            result = package(source, root / 'output')
            with zipfile.ZipFile(result['path']) as ipa:
                self.assertTrue(all(n.startswith('Payload/Runner.app/') for n in ipa.namelist()))
                self.assertEqual(ipa.getinfo('Payload/Runner.app/Runner').external_attr >> 16, 0o100755)
                self.assertEqual(ipa.getinfo('Payload/Runner.app/ResourcesLink').external_attr >> 16, 0o120777)
                self.assertEqual(ipa.read('Payload/Runner.app/ResourcesLink'), b'Frameworks')
            self.assertFalse(result['signed'])
            with self.assertRaises(FileExistsError):
                package(source, root / 'output')

    def test_simulator_build_is_not_packaged_as_device_ipa(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.fixture(root / 'app.zip', platform='iPhoneSimulator')
            with self.assertRaises(ValueError):
                package(root / 'app.zip', root / 'output')

    def test_flutter_fat_arm64_app_framework_is_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.fixture(root / 'app.zip', fat=True)
            result = package(root / 'app.zip', root / 'output')
            with zipfile.ZipFile(result['path']) as ipa:
                self.assertEqual(ipa.read('Payload/Runner.app/Frameworks/App.framework/App')[:4], b'\xca\xfe\xba\xbe')

    def test_unsafe_paths_and_signing_material_are_rejected(self):
        for extra in ['Runner.app/../secret', '/tmp/secret', 'Runner.app/embedded.mobileprovision', 'Runner.app/key.p12']:
            with self.subTest(extra=extra), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                self.fixture(root / 'app.zip', extra=extra)
                with self.assertRaises(ValueError):
                    package(root / 'app.zip', root / 'output')


if __name__ == '__main__':
    unittest.main()
