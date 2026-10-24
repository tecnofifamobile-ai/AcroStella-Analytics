import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const updateRepository = String.fromEnvironment(
  'UPDATE_REPOSITORY',
  defaultValue: 'tecnofifamobile-ai/AcroStella-Updates',
);
const updatePackage = 'com.acrostella.acrostella_analytics';
const iosUpdatePackage = 'com.acrostella.acrostellaAnalytics';

enum UpdatePlatform { android, ios }

const maxUpdateBytes = 350 * 1024 * 1024;

class UpdateFailure implements Exception {
  const UpdateFailure(this.message);
  final String message;
}

class UpdateCancelled implements Exception {}

class UpdateCancellation {
  bool cancelled = false;
  final _listeners = <void Function()>[];
  void cancel() {
    if (cancelled) return;
    cancelled = true;
    for (final callback in List.of(_listeners)) {
      callback();
    }
  }

  void check() {
    if (cancelled) throw UpdateCancelled();
  }

  void add(void Function() callback) => _listeners.add(callback);
  void remove(void Function() callback) => _listeners.remove(callback);
}

class UpdateResponse {
  UpdateResponse(this.status, this.body, this.close);
  final int status;
  final Stream<List<int>> body;
  final void Function() close;
}

abstract interface class UpdateTransport {
  Future<UpdateResponse> get(Uri uri, UpdateCancellation cancellation);
}

/// Public GitHub downloads only. No tokens, browser, TLS overrides or uploads.
class GitHubTransport implements UpdateTransport {
  static const _hosts = {
    'api.github.com',
    'github.com',
    'release-assets.githubusercontent.com',
    'objects.githubusercontent.com',
    'raw.githubusercontent.com',
  };

  @override
  Future<UpdateResponse> get(Uri uri, UpdateCancellation cancellation) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    client.findProxy = HttpClient.findProxyFromEnvironment;
    void abort() => client.close(force: true);
    cancellation.add(abort);
    try {
      for (var redirects = 0; redirects <= 5; redirects++) {
        cancellation.check();
        if (uri.scheme != 'https' ||
            !_hosts.contains(uri.host) ||
            uri.userInfo.isNotEmpty ||
            uri.hasPort) {
          throw const UpdateFailure('El enlace de actualización no es válido.');
        }
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 20));
        request.followRedirects = false;
        request.headers.set(HttpHeaders.userAgentHeader, 'AcroStella-Updates');
        if (uri.host == 'api.github.com') {
          request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
        }
        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.listen((_) {}).cancel();
          if (location == null) break;
          uri = uri.resolve(location);
          continue;
        }
        Stream<List<int>> stream() async* {
          try {
            yield* response.timeout(const Duration(seconds: 30));
          } finally {
            cancellation.remove(abort);
            abort();
          }
        }

        return UpdateResponse(response.statusCode, stream(), () {
          cancellation.remove(abort);
          abort();
        });
      }
      throw const UpdateFailure('No se pudo seguir el enlace de descarga.');
    } catch (_) {
      cancellation.remove(abort);
      abort();
      cancellation.check();
      rethrow;
    }
  }
}

class UpdateRelease {
  const UpdateRelease({
    required this.versionCode,
    required this.versionName,
    required this.notes,
    required this.apk,
    required this.bytes,
    required this.sha256,
    required this.minSdk,
    this.platform = UpdatePlatform.android,
    this.minimumOSVersion,
  });
  final int versionCode;
  final String versionName;
  final String notes;
  final Uri apk;
  final int bytes;
  final String sha256;
  final int minSdk;
  final UpdatePlatform platform;
  final String? minimumOSVersion;

  factory UpdateRelease.fromManifest(
    Map<String, dynamic> manifest,
    Uri apk,
    int assetBytes,
  ) {
    final code = manifest['version_code'];
    final name = manifest['version_name'];
    final bytes = manifest['bytes'];
    final hash = manifest['sha256'];
    final sdk = manifest['min_sdk'];
    final notes = manifest['notes'];
    if (manifest['schema'] != 1 ||
        manifest['package'] != updatePackage ||
        code is! int ||
        code <= 0 ||
        name is! String ||
        name.isEmpty ||
        name.length > 50 ||
        bytes is! int ||
        bytes <= 0 ||
        bytes > maxUpdateBytes ||
        bytes != assetBytes ||
        hash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        sdk is! int ||
        sdk < 24 ||
        notes is! String ||
        notes.length > 4000) {
      throw const UpdateFailure(
        'La información de actualización no es válida.',
      );
    }
    return UpdateRelease(
      versionCode: code,
      versionName: name,
      notes: notes,
      apk: apk,
      bytes: bytes,
      sha256: hash,
      minSdk: sdk,
    );
  }
}

abstract interface class UpdateSource {
  Future<UpdateRelease?> latest(UpdateCancellation cancellation);
  Future<File> download(
    UpdateRelease release,
    Directory directory,
    UpdateCancellation cancellation,
    void Function(int bytes) progress,
  );
}

class GitHubUpdateSource implements UpdateSource {
  GitHubUpdateSource({
    this.repository = updateRepository,
    UpdateTransport? transport,
  }) : _transport = transport ?? GitHubTransport() {
    if (!RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repository)) {
      throw ArgumentError.value(repository, 'repository');
    }
  }
  final String repository;
  final UpdateTransport _transport;

  Uri _assetUri(Object? value) {
    if (value is! String) {
      throw const UpdateFailure('Falta el enlace del instalador.');
    }
    final uri = Uri.tryParse(value);
    final pinnedFile =
        uri != null &&
        uri.host == 'raw.githubusercontent.com' &&
        uri.pathSegments.length == 6 &&
        uri.pathSegments.take(2).join('/') == repository &&
        uri.pathSegments[2] == 'refs' &&
        uri.pathSegments[3] == 'tags' &&
        RegExp(r'^v\d+\.\d+\.\d+\+\d+$').hasMatch(uri.pathSegments[4]) &&
        RegExp(r'^[A-Za-z0-9_.+-]+$').hasMatch(uri.pathSegments[5]);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        !(pinnedFile ||
            (uri.host == 'github.com' &&
                uri.path.startsWith('/$repository/releases/download/')))) {
      throw const UpdateFailure(
        'El instalador no pertenece al canal de actualización.',
      );
    }
    return uri;
  }

  Future<Map<String, dynamic>?> _json(
    Uri uri,
    UpdateCancellation cancellation, {
    required int maxBytes,
    bool allowMissing = false,
  }) async {
    final response = await _transport.get(uri, cancellation);
    try {
      if (response.status == 404 && allowMissing) return null;
      if (response.status != 200) {
        throw const UpdateFailure(
          'No se pudieron consultar las actualizaciones. Reintenta más tarde.',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.body) {
        cancellation.check();
        if (bytes.length + chunk.length > maxBytes) {
          throw const UpdateFailure(
            'La información de actualización supera el tamaño permitido.',
          );
        }
        bytes.addAll(chunk);
      }
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } finally {
      response.close();
    }
  }

  @override
  Future<UpdateRelease?> latest(UpdateCancellation cancellation) async {
    final release = await _json(
      Uri.https('api.github.com', '/repos/$repository/releases/latest'),
      cancellation,
      maxBytes: 512 * 1024,
      allowMissing: true,
    );
    if (release == null) return null;
    if (release['draft'] != false ||
        release['prerelease'] != false ||
        release['assets'] is! List) {
      throw const UpdateFailure('No hay una versión estable disponible.');
    }
    final assets = (release['assets'] as List).cast<Map<String, dynamic>>();
    final manifestAsset = assets
        .where((a) => a['name'] == 'acrostella-update.json')
        .firstOrNull;
    if (manifestAsset == null) {
      // Git-backed installers are an alternative when the publisher cannot
      // access uploads.github.com. Pin both files to an immutable release tag.
      final tag = release['tag_name'];
      if (assets.isNotEmpty ||
          tag is! String ||
          !RegExp(r'^v\d+\.\d+\.\d+\+\d+$').hasMatch(tag)) {
        throw const UpdateFailure(
          'La versión publicada no contiene información de actualización.',
        );
      }
      Uri pinned(String name) => _assetUri(
        Uri(
          scheme: 'https',
          host: 'raw.githubusercontent.com',
          pathSegments: [...repository.split('/'), 'refs', 'tags', tag, name],
        ).toString(),
      );
      final manifest = (await _json(
        pinned('acrostella-update.json'),
        cancellation,
        maxBytes: 16 * 1024,
      ))!;
      final name = manifest['apk_asset'];
      if (name is! String ||
          !RegExp(r'^[A-Za-z0-9_.+-]+\.apk$').hasMatch(name) ||
          manifest['bytes'] is! int) {
        throw const UpdateFailure('El nombre del instalador no es válido.');
      }
      final candidate = UpdateRelease.fromManifest(
        manifest,
        pinned(name),
        manifest['bytes'] as int,
      );
      if (tag != 'v${candidate.versionName}+${candidate.versionCode}') {
        throw const UpdateFailure('La versión no coincide con su publicación.');
      }
      return candidate;
    }
    final manifest = (await _json(
      _assetUri(manifestAsset['browser_download_url']),
      cancellation,
      maxBytes: 16 * 1024,
    ))!;
    final apk = assets
        .where((a) => a['name'] == manifest['apk_asset'])
        .firstOrNull;
    if (apk == null ||
        apk['size'] is! int ||
        !(apk['name'] as String).endsWith('.apk')) {
      throw const UpdateFailure(
        'La versión publicada no contiene un APK compatible.',
      );
    }
    return UpdateRelease.fromManifest(
      manifest,
      _assetUri(apk['browser_download_url']),
      apk['size'] as int,
    );
  }

  @override
  Future<File> download(
    UpdateRelease release,
    Directory directory,
    UpdateCancellation cancellation,
    void Function(int bytes) progress,
  ) async {
    if (release.bytes <= 0 || release.bytes > maxUpdateBytes) {
      throw const UpdateFailure('El instalador supera el tamaño permitido.');
    }
    _assetUri(release.apk.toString());
    final extension = release.platform == UpdatePlatform.ios ? 'ipa' : 'apk';
    await directory.create(recursive: true);
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File &&
          RegExp(r'^acrostella-\d+\.' + extension + r'\.part$')
              .hasMatch(entry.uri.pathSegments.last)) {
        await entry.delete();
      }
    }
    final partial = File(
      '${directory.path}/acrostella-${release.versionCode}.$extension.part',
    );
    final complete = File(
      '${directory.path}/acrostella-${release.versionCode}.$extension',
    );
    final response = await _transport.get(release.apk, cancellation);
    RandomAccessFile? output;
    try {
      if (response.status != 200) {
        throw const UpdateFailure('No se pudo descargar el instalador.');
      }
      output = await partial.open(mode: FileMode.write);
      Digest? digest;
      final hasher = sha256.startChunkedConversion(
        _DigestCollector((value) => digest = value),
      );
      var received = 0;
      await for (final chunk in response.body) {
        cancellation.check();
        received += chunk.length;
        if (received > release.bytes) {
          throw const UpdateFailure('El tamaño del instalador no coincide.');
        }
        hasher.add(chunk);
        await output.writeFrom(chunk);
        progress(received);
      }
      cancellation.check();
      hasher.close();
      if (received != release.bytes || digest.toString() != release.sha256) {
        throw const UpdateFailure(
          'No se pudo verificar la descarga. Vuelve a intentarlo.',
        );
      }
      await output.flush();
      await output.close();
      output = null;
      final verified = await partial.rename(complete.path);
      // This cache contains installers only; it never touches recorded clips.
      final older = <File>[];
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is File &&
            entry.path != verified.path &&
            RegExp(r'^acrostella-\d+\.' + extension + r'$')
                .hasMatch(entry.uri.pathSegments.last)) {
          older.add(entry);
        }
      }
      older.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
      for (final old in older.skip(1)) {
        try {
          await old.delete();
        } on FileSystemException {
          /* Retry cleanup on the next download. */
        }
      }
      return verified;
    } finally {
      response.close();
      await output?.close();
      if (await partial.exists()) await partial.delete();
    }
  }
}

/// Read the public repository HEAD through the API, then pin the manifest to
/// that immutable commit. This does not use a cached Flarestore catalogue.
class GitHubIosUpdateSource extends GitHubUpdateSource {
  GitHubIosUpdateSource({super.repository, super.transport});

  @override
  Uri _assetUri(Object? value) {
    final uri = value is String ? Uri.tryParse(value) : null;
    final p = uri?.pathSegments ?? [];
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'raw.githubusercontent.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        p.length != 6 ||
        p.take(2).join('/') != repository ||
        p[2] != 'refs' ||
        p[3] != 'tags' ||
        !RegExp(r'^ios-v\d+\.\d+\.\d+\+\d+$').hasMatch(p[4]) ||
        !RegExp(r'^acrostella-analytics-\d+\.\d+\.\d+\+\d+-unsigned\.ipa$')
            .hasMatch(p[5])) {
      throw const UpdateFailure('La IPA no pertenece al canal de AcroStella.');
    }
    return uri;
  }

  @override
  Future<UpdateRelease?> latest(UpdateCancellation cancellation) async {
    final head = await _json(
      Uri.https('api.github.com', '/repos/$repository/commits/main'),
      cancellation,
      maxBytes: 512 * 1024,
    );
    final commit = head?['sha'];
    if (commit is! String || !RegExp(r'^[a-f0-9]{40}$').hasMatch(commit)) {
      throw const UpdateFailure('No se pudo comprobar la publicación de iOS.');
    }
    final manifest = await _json(
      Uri.https(
        'raw.githubusercontent.com',
        '/$repository/$commit/acrostella-ios-update.json',
      ),
      cancellation,
      maxBytes: 16 * 1024,
      allowMissing: true,
    );
    if (manifest == null) return null;
    final version = manifest['version_name'], code = manifest['version_code'];
    final size = manifest['bytes'], hash = manifest['sha256'];
    final minimum = manifest['min_os'], notes = manifest['notes'];
    if (manifest['schema'] != 1 ||
        manifest['platform'] != 'ios' ||
        manifest['package'] != iosUpdatePackage ||
        version is! String ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
        code is! int ||
        code < 1 ||
        size is! int ||
        size < 1 ||
        size > maxUpdateBytes ||
        hash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        minimum is! String ||
        !RegExp(r'^\d+\.\d+(?:\.\d+)?$').hasMatch(minimum) ||
        notes is! String ||
        notes.length > 4000) {
      throw const UpdateFailure(
        'La información de actualización iOS no es válida.',
      );
    }
    final uri = _assetUri(manifest['download_url']);
    final tag = 'ios-v$version+$code';
    if (uri.pathSegments[4] != tag ||
        uri.pathSegments.last !=
            'acrostella-analytics-$version+$code-unsigned.ipa') {
      throw const UpdateFailure('La versión iOS no coincide con su descarga.');
    }
    final published = await _json(
      Uri.https('api.github.com', '/repos/$repository/releases/tags/$tag'),
      cancellation,
      maxBytes: 512 * 1024,
    );
    if (published?['draft'] != false || published?['tag_name'] != tag) {
      throw const UpdateFailure(
        'La actualización iOS todavía no está publicada.',
      );
    }
    return UpdateRelease(
      versionCode: code,
      versionName: version,
      notes: notes,
      apk: uri,
      bytes: size,
      sha256: hash,
      minSdk: 0,
      platform: UpdatePlatform.ios,
      minimumOSVersion: minimum,
    );
  }
}

class _DigestCollector implements Sink<Digest> {
  _DigestCollector(this._receive);
  final void Function(Digest) _receive;
  @override
  void add(Digest data) => _receive(data);
  @override
  void close() {}
}
