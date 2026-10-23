import 'dart:convert';
import 'dart:io';

import 'package:acrostella_analytics/src/updates/update_source.dart';
import 'package:flutter_test/flutter_test.dart';

const abcHash =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
const assetRoot =
    'https://github.com/tecnofifamobile-ai/AcroStella-Updates/releases/download/v0.4.0+4/';

class QueueTransport implements UpdateTransport {
  final replies = <String, UpdateResponse>{};
  final requests = <Uri>[];
  int closes = 0;
  void json(Uri uri, Object data) => replies[uri.toString()] = UpdateResponse(
    200,
    Stream.value(utf8.encode(jsonEncode(data))),
    () => closes++,
  );
  @override
  Future<UpdateResponse> get(Uri uri, UpdateCancellation cancellation) async {
    cancellation.check();
    requests.add(uri);
    return replies.remove(uri.toString())!;
  }
}

UpdateRelease testRelease({String hash = abcHash, int bytes = 3}) =>
    UpdateRelease(
      versionCode: 4,
      versionName: '0.4.0',
      notes: 'Mejoras',
      apk: Uri.parse('${assetRoot}app.apk'),
      bytes: bytes,
      sha256: hash,
      minSdk: 24,
    );

void main() {
  late QueueTransport transport;
  late GitHubUpdateSource source;
  late Directory directory;
  final endpoint = Uri.parse(
    'https://api.github.com/repos/tecnofifamobile-ai/AcroStella-Updates/releases/latest',
  );
  late Map<String, dynamic> manifest;
  late Map<String, dynamic> release;

  void prepare() {
    transport.json(endpoint, release);
    transport.json(Uri.parse('${assetRoot}acrostella-update.json'), manifest);
  }

  setUp(() async {
    transport = QueueTransport();
    source = GitHubUpdateSource(transport: transport);
    directory = await Directory.systemTemp.createTemp(
      'acrostella-update-test-',
    );
    manifest = {
      'schema': 1,
      'package': updatePackage,
      'version_code': 4,
      'version_name': '0.4.0',
      'notes': 'Mejoras',
      'min_sdk': 24,
      'bytes': 3,
      'sha256': abcHash,
      'apk_asset': 'app.apk',
    };
    release = {
      'draft': false,
      'prerelease': false,
      'assets': [
        {
          'name': 'acrostella-update.json',
          'browser_download_url': '${assetRoot}acrostella-update.json',
        },
        {
          'name': 'app.apk',
          'browser_download_url': '${assetRoot}app.apk',
          'size': 3,
        },
      ],
    };
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'reads public release and bounded manifest without authentication',
    () async {
      prepare();
      final result = (await source.latest(UpdateCancellation()))!;
      expect(result.versionCode, 4);
      expect(result.sha256, abcHash);
      expect(transport.requests, [
        endpoint,
        Uri.parse('${assetRoot}acrostella-update.json'),
      ]);
    },
  );

  test('missing release is a normal empty feed', () async {
    transport.replies[endpoint.toString()] = UpdateResponse(
      404,
      const Stream.empty(),
      () => transport.closes++,
    );
    expect(await source.latest(UpdateCancellation()), isNull);
    expect(transport.closes, 1);
  });

  Uri pinned(String name) => Uri(
    scheme: 'https',
    host: 'raw.githubusercontent.com',
    pathSegments: [
      'tecnofifamobile-ai',
      'AcroStella-Updates',
      'refs',
      'tags',
      'v0.4.0+4',
      name,
    ],
  );

  test(
    'reads and downloads Git-backed APK pinned to the release tag',
    () async {
      release['assets'] = [];
      release['tag_name'] = 'v0.4.0+4';
      transport.json(endpoint, release);
      transport.json(pinned('acrostella-update.json'), manifest);
      transport.replies[pinned('app.apk').toString()] = UpdateResponse(
        200,
        Stream.value(utf8.encode('abc')),
        () {},
      );
      final candidate = (await source.latest(UpdateCancellation()))!;
      final file = await source.download(
        candidate,
        directory,
        UpdateCancellation(),
        (_) {},
      );
      expect(await file.readAsString(), 'abc');
      expect(candidate.apk, pinned('app.apk'));
    },
  );

  for (final tag in ['main', '../main', 'v0.4.0/4']) {
    test('rejects mutable or malformed release tag $tag', () async {
      release['assets'] = [];
      release['tag_name'] = tag;
      transport.json(endpoint, release);
      await expectLater(
        source.latest(UpdateCancellation()),
        throwsA(isA<UpdateFailure>()),
      );
      expect(transport.requests, [endpoint]);
    });
  }

  for (final field in ['apk_asset', 'version_code']) {
    test('rejects Git-backed manifest with invalid $field', () async {
      release['assets'] = [];
      release['tag_name'] = 'v0.4.0+4';
      manifest[field] = field == 'apk_asset' ? '../other.apk' : 5;
      transport.json(endpoint, release);
      transport.json(pinned('acrostella-update.json'), manifest);
      await expectLater(
        source.latest(UpdateCancellation()),
        throwsA(isA<UpdateFailure>()),
      );
    });
  }

  for (final mutation in ['package', 'sha256', 'bytes', 'schema']) {
    test('rejects invalid manifest $mutation', () async {
      manifest[mutation] = switch (mutation) {
        'bytes' => maxUpdateBytes + 1,
        'schema' => 2,
        _ => 'invalid',
      };
      prepare();
      await expectLater(
        source.latest(UpdateCancellation()),
        throwsA(isA<UpdateFailure>()),
      );
    });
  }

  test('does not offer draft or prerelease builds', () async {
    release['prerelease'] = true;
    prepare();
    await expectLater(
      source.latest(UpdateCancellation()),
      throwsA(isA<UpdateFailure>()),
    );
  });

  test('rejects download assets from a different repository', () async {
    (release['assets'] as List)[1]['browser_download_url'] =
        'https://github.com/other/repo/releases/download/v1/app.apk';
    prepare();
    await expectLater(
      source.latest(UpdateCancellation()),
      throwsA(isA<UpdateFailure>()),
    );
  });

  test(
    'production transport rejects cleartext before making a request',
    () async {
      await expectLater(
        GitHubTransport().get(
          Uri.parse('http://github.com/file'),
          UpdateCancellation(),
        ),
        throwsA(isA<UpdateFailure>()),
      );
    },
  );

  test(
    'streams to disk and publishes file only after matching size and hash',
    () async {
      final candidate = testRelease();
      transport.replies[candidate.apk.toString()] = UpdateResponse(
        200,
        Stream.fromIterable([utf8.encode('ab'), utf8.encode('c')]),
        () {},
      );
      final progress = <int>[];
      final file = await source.download(
        candidate,
        directory,
        UpdateCancellation(),
        progress.add,
      );
      expect(await file.readAsString(), 'abc');
      expect(progress, [2, 3]);
      expect(await File('${file.path}.part').exists(), isFalse);
    },
  );

  for (final bytes in ['ab', 'abcd', 'xyz']) {
    test(
      'rejects truncated oversized or tampered payload $bytes and cleans partial',
      () async {
        final candidate = testRelease();
        transport.replies[candidate.apk.toString()] = UpdateResponse(
          200,
          Stream.value(utf8.encode(bytes)),
          () {},
        );
        await expectLater(
          source.download(candidate, directory, UpdateCancellation(), (_) {}),
          throwsA(isA<UpdateFailure>()),
        );
        expect(await directory.list().toList(), isEmpty);
      },
    );
  }

  test(
    'cancelling midstream removes partial and never exposes an installer',
    () async {
      final candidate = testRelease();
      final cancellation = UpdateCancellation();
      transport.replies[candidate.apk.toString()] = UpdateResponse(
        200,
        Stream.fromIterable([
          [97],
          [98],
          [99],
        ]),
        () {},
      );
      await expectLater(
        source.download(
          candidate,
          directory,
          cancellation,
          (_) => cancellation.cancel(),
        ),
        throwsA(isA<UpdateCancelled>()),
      );
      expect(await directory.list().toList(), isEmpty);
    },
  );

  test('rejects oversized metadata before decoding it', () async {
    transport.replies[endpoint.toString()] = UpdateResponse(
      200,
      Stream.value(List.filled(512 * 1024 + 1, 32)),
      () {},
    );
    await expectLater(
      source.latest(UpdateCancellation()),
      throwsA(isA<UpdateFailure>()),
    );
  });
}
