import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'update_source.dart';

class InstalledApp {
  const InstalledApp(
    this.versionCode,
    this.versionName,
    this.sdk,
    this.canInstall, {
    this.platform = UpdatePlatform.android,
    this.osVersion,
  });
  final int versionCode;
  final String versionName;
  final int sdk;
  final bool canInstall;
  final UpdatePlatform platform;
  final String? osVersion;
  bool supports(UpdateRelease release) {
    if (release.platform != platform) return false;
    if (platform == UpdatePlatform.android) return release.minSdk <= sdk;
    if (osVersion == null || release.minimumOSVersion == null) return false;
    final ours = osVersion!.split('.').map(int.parse).toList();
    final minimum = release.minimumOSVersion!
        .split('.')
        .map(int.parse)
        .toList();
    for (var i = 0; i < 3; i++) {
      final a = i < ours.length ? ours[i] : 0;
      final b = i < minimum.length ? minimum[i] : 0;
      if (a != b) return a > b;
    }
    return true;
  }
}

abstract interface class UpdateInstaller {
  Future<InstalledApp> installed();
  Future<void> verify(File apk, UpdateRelease release);
  Future<void> openPermission();
  Future<void> install(File apk, UpdateRelease release);
}

class AndroidUpdateInstaller implements UpdateInstaller {
  static const _channel = MethodChannel('acrostella/updates');

  @override
  Future<InstalledApp> installed() async {
    final value = (await _channel.invokeMapMethod<String, dynamic>(
      'installed',
    ))!;
    return InstalledApp(
      value['code'] as int,
      value['name'] as String,
      value['sdk'] as int,
      value['canInstall'] as bool,
    );
  }

  Map<String, dynamic> _arguments(File file, UpdateRelease release) => {
    'path': file.path,
    'sha256': release.sha256,
    'code': release.versionCode,
    'bytes': release.bytes,
  };

  @override
  Future<void> verify(File apk, UpdateRelease release) async {
    await _channel.invokeMethod<void>('verify', _arguments(apk, release));
  }

  @override
  Future<void> install(File apk, UpdateRelease release) async {
    await _channel.invokeMethod<void>('install', _arguments(apk, release));
  }

  @override
  Future<void> openPermission() => _channel.invokeMethod<void>('permission');
}

class UpdatePreferences {
  const UpdatePreferences({this.automatic = true, this.lastCheck});
  final bool automatic;
  final DateTime? lastCheck;
}

abstract interface class UpdatePreferencesStore {
  Future<UpdatePreferences> read();
  Future<void> write(UpdatePreferences preferences);
}

class FileUpdatePreferences implements UpdatePreferencesStore {
  FileUpdatePreferences(this._directory);
  final Future<Directory> Function() _directory;
  Future<void> _writing = Future<void>.value();

  @override
  Future<UpdatePreferences> read() async {
    final file = File('${(await _directory()).path}/update_settings.json');
    if (!await file.exists()) return const UpdatePreferences();
    try {
      if (await file.length() > 1024) return const UpdatePreferences();
      final value =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return UpdatePreferences(
        automatic: value['automatic'] is bool
            ? value['automatic'] as bool
            : true,
        lastCheck: DateTime.tryParse(value['lastCheck'] as String? ?? ''),
      );
    } on FormatException {
      return const UpdatePreferences();
    } on TypeError {
      return const UpdatePreferences();
    }
  }

  @override
  Future<void> write(UpdatePreferences preferences) {
    final next = _writing.then((_) => _write(preferences));
    _writing = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _write(UpdatePreferences preferences) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final temporary = File('${directory.path}/update_settings.pending');
    await temporary.writeAsString(
      jsonEncode({
        'automatic': preferences.automatic,
        'lastCheck': preferences.lastCheck?.toUtc().toIso8601String(),
      }),
      flush: true,
    );
    await temporary.rename('${directory.path}/update_settings.json');
  }
}

enum UpdatePhase {
  idle,
  checking,
  current,
  available,
  downloading,
  ready,
  installing,
  failed,
  incompatible,
}

class UpdateController extends ChangeNotifier {
  UpdateController({
    required this.source,
    required this.installer,
    required this.preferences,
    required this.downloadDirectory,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final UpdateSource source;
  final UpdateInstaller installer;
  final UpdatePreferencesStore preferences;
  final Future<Directory> Function() downloadDirectory;
  final DateTime Function() _now;
  UpdatePhase phase = UpdatePhase.idle;
  InstalledApp? app;
  UpdateRelease? release;
  String? message;
  int received = 0;
  bool automatic = true;
  bool dismissed = false;
  bool _disposed = false;
  DateTime? _lastCheck;
  UpdateCancellation? _cancellation;
  File? _apk;
  Future<void>? _initializing;

  bool get busy => [
    UpdatePhase.checking,
    UpdatePhase.downloading,
    UpdatePhase.installing,
  ].contains(phase);
  bool get hasUpdate =>
      release != null && app != null && release!.versionCode > app!.versionCode;
  bool get showNotice =>
      hasUpdate &&
      !dismissed &&
      [UpdatePhase.available, UpdatePhase.ready].contains(phase);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initializing ??= _load();
  Future<void> _load() async {
    try {
      final saved = await preferences.read();
      automatic = saved.automatic;
      _lastCheck = saved.lastCheck;
      app = await installer.installed();
    } catch (_) {
      message =
          'No se pudo preparar el actualizador. Puedes reintentar la búsqueda.';
    }
    _notify();
  }

  Future<void> checkAutomatically() async {
    await initialize();
    if (_disposed ||
        busy ||
        !automatic ||
        (_lastCheck != null &&
            _now().difference(_lastCheck!) < const Duration(hours: 24))) {
      return;
    }
    await check();
  }

  Future<void> setAutomatic(bool enabled) async {
    final old = automatic;
    automatic = enabled;
    _notify();
    try {
      await preferences.write(
        UpdatePreferences(automatic: automatic, lastCheck: _lastCheck),
      );
    } catch (_) {
      automatic = old;
      message = 'No se pudo guardar la preferencia de actualizaciones.';
      _notify();
    }
  }

  Future<void> check() async {
    if (_disposed || busy) return;
    phase = UpdatePhase.checking;
    message = null;
    _notify();
    final cancellation = UpdateCancellation();
    _cancellation = cancellation;
    try {
      await initialize();
      app = await installer.installed();
      final latest = await source.latest(cancellation);
      if (_disposed) return;
      release = latest;
      _apk = null;
      dismissed = false;
      _lastCheck = _now();
      try {
        await preferences.write(
          UpdatePreferences(automatic: automatic, lastCheck: _lastCheck),
        );
      } catch (_) {
        /* A settings write must not hide a valid update result. */
      }
      if (latest == null || latest.versionCode <= app!.versionCode) {
        phase = UpdatePhase.current;
        message = latest == null
            ? 'Todavía no hay actualizaciones publicadas.'
            : 'Ya tienes la última versión.';
      } else if (!app!.supports(latest)) {
        phase = UpdatePhase.incompatible;
        message = app!.platform == UpdatePlatform.ios
            ? 'La nueva versión requiere iOS/iPadOS ${latest.minimumOSVersion} o posterior.'
            : 'La nueva versión requiere una versión de Android más reciente.';
      } else {
        phase = UpdatePhase.available;
      }
    } catch (error) {
      if (_disposed) return;
      phase = UpdatePhase.failed;
      message = error is UpdateFailure
          ? error.message
          : 'No se pudo conectar. Comprueba Internet y vuelve a intentarlo.';
    } finally {
      _cancellation = null;
      _notify();
    }
  }

  void dismissNotice() {
    dismissed = true;
    _notify();
  }

  Future<void> download() async {
    if (_disposed || busy || !hasUpdate || phase == UpdatePhase.incompatible) {
      return;
    }
    final candidate = release!;
    phase = UpdatePhase.downloading;
    received = 0;
    message = null;
    final cancellation = UpdateCancellation();
    _cancellation = cancellation;
    final clock = Stopwatch()..start();
    var lastNotification = 0;
    File? downloaded;
    _notify();
    try {
      downloaded = await source.download(
        candidate,
        await downloadDirectory(),
        cancellation,
        (bytes) {
          received = bytes;
          if (clock.elapsedMilliseconds - lastNotification >= 100 ||
              bytes == candidate.bytes) {
            lastNotification = clock.elapsedMilliseconds;
            _notify();
          }
        },
      );
      cancellation.check();
      await installer.verify(downloaded, candidate);
      cancellation.check();
      if (_disposed) return;
      _apk = downloaded;
      phase = UpdatePhase.ready;
      message = candidate.platform == UpdatePlatform.ios
          ? 'IPA verificada. Envíala al firmador para firmar e instalar.'
          : 'Descarga verificada. Puedes instalar la actualización.';
    } catch (error) {
      if (downloaded != null && await downloaded.exists()) {
        try {
          await downloaded.delete();
        } on FileSystemException {
          // Cleanup failure must never make an unverified APK installable.
        }
      }
      if (_disposed) return;
      phase = error is UpdateCancelled || cancellation.cancelled
          ? UpdatePhase.available
          : UpdatePhase.failed;
      message = error is UpdateCancelled || cancellation.cancelled
          ? 'Descarga cancelada.'
          : error is UpdateFailure
          ? error.message
          : error is FileSystemException
          ? 'No se pudo guardar el instalador. Comprueba el espacio disponible.'
          : 'El instalador no es compatible con esta instalación. Comprueba que usas el canal correcto.';
    } finally {
      clock.stop();
      _cancellation = null;
      _notify();
    }
  }

  void cancelDownload() => _cancellation?.cancel();

  Future<void> install() async {
    if (_disposed ||
        phase != UpdatePhase.ready ||
        _apk == null ||
        release == null) {
      return;
    }
    phase = UpdatePhase.installing;
    _notify();
    try {
      app = await installer.installed();
      if (app!.versionCode >= release!.versionCode) {
        phase = UpdatePhase.current;
        message = 'La aplicación está actualizada.';
        _notify();
        return;
      }
      if (!app!.canInstall) {
        await installer.openPermission();
        message = 'Permite instalar actualizaciones de AcroStella y vuelve aquí para pulsar Instalar.';
        phase = UpdatePhase.ready;
      } else {
        // Native code rechecks hash, package, version and signer immediately
        // before sharing the private FileProvider URI with Android's installer.
        await installer.install(_apk!, release!);
        if (release!.platform == UpdatePlatform.ios) {
          phase = UpdatePhase.ready;
          message = 'Firma e instala la IPA en Flarestore conservando el identificador anterior. Compartir el archivo no confirma la instalación.';
        } else {
          message = 'Confirma la instalación en la pantalla de Android.';
        }
      }
    } catch (error) {
      final invalid =
          error is UpdateFailure ||
          error is PlatformException && error.code == 'invalid_update';
      phase = invalid ? UpdatePhase.failed : UpdatePhase.ready;
      if (invalid) _apk = null;
      message = invalid
          ? 'El instalador ya no es válido. Vuelve a descargar la actualización.'
          : release?.platform == UpdatePlatform.ios
          ? 'No se pudo compartir la IPA. Vuelve a pulsar Enviar IPA al firmador.'
          : 'No se pudo abrir el instalador. Revisa el permiso y vuelve a intentarlo.';
    }
    _notify();
  }

  Future<void> resumed() async {
    if (_disposed ||
        phase == UpdatePhase.downloading ||
        phase == UpdatePhase.checking) {
      return;
    }
    try {
      app = await installer.installed();
      if (phase == UpdatePhase.installing) phase = UpdatePhase.ready;
      if (release != null && app!.versionCode >= release!.versionCode) {
        phase = UpdatePhase.current;
        message = 'La aplicación está actualizada.';
      }
      _notify();
    } catch (_) {
      /* Retry explicitly without interrupting the camera UI. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancellation?.cancel();
    super.dispose();
  }
}
