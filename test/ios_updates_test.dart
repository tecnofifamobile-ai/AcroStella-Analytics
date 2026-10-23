import 'dart:io';

import 'package:acrostella_analytics/src/updates/ios_update_installer.dart';
import 'package:acrostella_analytics/src/updates/update_controller.dart';
import 'package:acrostella_analytics/src/updates/update_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'update_source_test.dart' show QueueTransport, abcHash;
import 'update_controller_test.dart'
    show MemoryUpdatePreferences, TestUpdateInstaller, TestUpdateSource;

void main() {
  late Directory directory;
  late QueueTransport transport;
  late GitHubIosUpdateSource source;
  final head = Uri.https(
    'api.github.com',
    '/repos/$updateRepository/commits/main',
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('acrostella-ios-update-');
    transport = QueueTransport();
    source = GitHubIosUpdateSource(transport: transport);
  });
  tearDown(() => directory.delete(recursive: true));

  Map<String, dynamic> manifest({int code = 7, String hash = abcHash}) => {
    'schema': 1,
    'platform': 'ios',
    'package': iosUpdatePackage,
    'version_name': '0.5.2',
    'version_code': code,
    'min_os': '15.0',
    'bytes': 3,
    'sha256': hash,
    'notes': 'iOS updates',
    'download_url':
        'https://raw.githubusercontent.com/$updateRepository/refs/tags/ios-v0.5.2%2B$code/acrostella-analytics-0.5.2%2B$code-unsigned.ipa',
  };
  void prepare(String commit, Map<String, dynamic> data, {bool draft = false}) {
    transport.json(head, {'sha': commit});
    transport.json(
      Uri.https(
        'raw.githubusercontent.com',
        '/$updateRepository/$commit/acrostella-ios-update.json',
      ),
      data,
    );
    final tag = 'ios-v${data['version_name']}+${data['version_code']}';
    transport.json(
      Uri.https(
        'api.github.com',
        '/repos/$updateRepository/releases/tags/$tag',
      ),
      {'tag_name': tag, 'draft': draft, 'prerelease': true},
    );
  }

  test('iOS reads fresh HEAD then immutable manifest, independently of cached Store sources and Android latest', () async {
    prepare('a' * 40, manifest(code: 6));
    expect((await source.latest(UpdateCancellation()))!.versionCode, 6);
    prepare('b' * 40, manifest());
    final release = (await source.latest(UpdateCancellation()))!;
    expect(release.versionCode, 7);
    expect(release.platform, UpdatePlatform.ios);
    expect(transport.requests.where((uri) => uri == head), hasLength(2));
    expect(
      transport.requests.any(
        (uri) =>
            uri.path.contains('flarestore') ||
            uri.path.endsWith('releases/latest'),
      ),
      isFalse,
    );
  });

  test(
    'iOS verifies the entire download and uses an IPA file extension',
    () async {
      prepare('a' * 40, manifest());
      final release = (await source.latest(UpdateCancellation()))!;
      transport.replies[release.apk.toString()] = UpdateResponse(
        200,
        Stream.fromIterable([
          [97],
          [98, 99],
        ]),
        () {},
      );
      final file = await source.download(
        release,
        directory,
        UpdateCancellation(),
        (_) {},
      );
      expect(file.path, endsWith('.ipa'));
      expect(await file.readAsString(), 'abc');
    },
  );

  test(
    'iOS rejects drafts, another bundle and an unpinned or mismatched URL',
    () async {
      prepare('a' * 40, manifest(), draft: true);
      await expectLater(
        source.latest(UpdateCancellation()),
        throwsA(isA<UpdateFailure>()),
      );
      for (final bad in [
        {...manifest(), 'package': 'another.app'},
        {...manifest(), 'download_url': 'https://example.com/file.ipa'},
        {
          ...manifest(),
          'download_url': (manifest()['download_url'] as String).replaceAll(
            'ios-v0.5.2%2B7',
            'main',
          ),
        },
        {...manifest(), 'version_code': 8},
      ]) {
        prepare('b' * 40, bad);
        await expectLater(
          source.latest(UpdateCancellation()),
          throwsA(isA<UpdateFailure>()),
        );
      }
    },
  );

  test('bad bytes or size never produce a shareable IPA and partial files are removed', () async {
    prepare('a' * 40, manifest(hash: 'a' * 64));
    final release = (await source.latest(UpdateCancellation()))!;
    transport.replies[release.apk.toString()] = UpdateResponse(
      200,
      Stream.value([97, 98, 99]),
      () {},
    );
    await expectLater(
      source.download(release, directory, UpdateCancellation(), (_) {}),
      throwsA(isA<UpdateFailure>()),
    );
    expect(await directory.list().toList(), isEmpty);
  });

  test('iOS handoff rechecks a modified IPA before sharing', () async {
    prepare('a' * 40, manifest());
    final release = (await source.latest(UpdateCancellation()))!;
    final file = await File('${directory.path}/app.ipa').writeAsString('abc');
    var shares = 0;
    final installer = IosUpdateInstaller(
      share: (_) async {
        shares++;
      },
    );
    await installer.install(file, release);
    expect(shares, 1);
    await file.writeAsString('xyz');
    await expectLater(
      installer.install(file, release),
      throwsA(isA<UpdateFailure>()),
    );
    expect(shares, 1);
  });

  test('iOS compatibility compares minor and patch versions and rejects another platform', () {
    const app = InstalledApp(
      6,
      '0.5.1',
      0,
      true,
      platform: UpdatePlatform.ios,
      osVersion: '15.3.1',
    );
    UpdateRelease release(String minimum) => UpdateRelease(
      versionCode: 7,
      versionName: '0.5.2',
      notes: '',
      apk: Uri.https('example.com', '/'),
      bytes: 3,
      sha256: abcHash,
      minSdk: 0,
      platform: UpdatePlatform.ios,
      minimumOSVersion: minimum,
    );
    expect(app.supports(release('15.3')), isTrue);
    expect(app.supports(release('15.3.2')), isFalse);
    expect(app.supports(release('16.0')), isFalse);
  });

  test('sharing an iOS update leaves it ready until installed build actually changes', () async {
    prepare('a' * 40, manifest());
    final release = (await source.latest(UpdateCancellation()))!;
    final installer = TestUpdateInstaller()
      ..app = const InstalledApp(
        6,
        '0.5.1',
        0,
        true,
        platform: UpdatePlatform.ios,
        osVersion: '27.0.1',
      );
    final fake = TestUpdateSource(directory)..release = release;
    final controller = UpdateController(
      source: fake,
      installer: installer,
      preferences: MemoryUpdatePreferences(),
      downloadDirectory: () async => directory,
    );
    try {
      await controller.check();
      expect(controller.phase, UpdatePhase.available);
      await controller.download();
      await controller.install();
      expect(controller.phase, UpdatePhase.ready);
      expect(controller.message, contains('Firma e instala'));
      await controller.resumed();
      expect(controller.phase, UpdatePhase.ready);
      installer.app = const InstalledApp(
        7,
        '0.5.2',
        0,
        true,
        platform: UpdatePlatform.ios,
        osVersion: '27.0.1',
      );
      await controller.resumed();
      expect(controller.phase, UpdatePhase.current);
    } finally {
      controller.dispose();
    }
  });
}
