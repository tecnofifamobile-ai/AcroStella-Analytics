import 'dart:async';
import 'dart:io';

import 'package:acrostella_analytics/src/updates/update_controller.dart';
import 'package:acrostella_analytics/src/updates/update_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'update_source_test.dart' show testRelease;

class MemoryUpdatePreferences implements UpdatePreferencesStore {
  UpdatePreferences value = const UpdatePreferences();
  @override
  Future<UpdatePreferences> read() async => value;
  @override
  Future<void> write(UpdatePreferences preferences) async =>
      value = preferences;
}

class TestUpdateInstaller implements UpdateInstaller {
  InstalledApp app = const InstalledApp(3, '0.3.0', 36, true);
  final calls = <String>[];
  bool failVerify = false;
  Completer<void>? verifying;
  @override
  Future<InstalledApp> installed() async => app;
  @override
  Future<void> verify(File apk, UpdateRelease release) async {
    calls.add('verify');
    if (failVerify) throw StateError('wrong signing certificate');
    await verifying?.future;
  }

  @override
  Future<void> openPermission() async => calls.add('permission');
  @override
  Future<void> install(File apk, UpdateRelease release) async =>
      calls.add('install');
}

class TestUpdateSource implements UpdateSource {
  TestUpdateSource(this.folder);
  final Directory folder;
  UpdateRelease? release = testRelease();
  int checks = 0;
  bool failCheck = false;
  @override
  Future<UpdateRelease?> latest(UpdateCancellation cancellation) async {
    checks++;
    if (failCheck) throw const UpdateFailure('Sin conexión.');
    return release;
  }

  @override
  Future<File> download(
    UpdateRelease release,
    Directory directory,
    UpdateCancellation cancellation,
    void Function(int) progress,
  ) async {
    final file = File('${folder.path}/download.apk');
    await file.writeAsString('abc');
    progress(3);
    return file;
  }
}

void main() {
  late Directory folder;
  late TestUpdateInstaller installer;
  late TestUpdateSource source;
  late MemoryUpdatePreferences preferences;
  late UpdateController controller;
  var now = DateTime.utc(2026, 10, 23);
  setUp(() async {
    folder = await Directory.systemTemp.createTemp(
      'acrostella-update-controller-',
    );
    installer = TestUpdateInstaller();
    source = TestUpdateSource(folder);
    preferences = MemoryUpdatePreferences();
    controller = UpdateController(
      source: source,
      installer: installer,
      preferences: preferences,
      downloadDirectory: () async => folder,
      now: () => now,
    );
  });
  tearDown(() async {
    controller.dispose();
    await folder.delete(recursive: true);
  });

  test(
    'offers a higher build and only becomes ready after native verification',
    () async {
      await controller.check();
      expect(controller.showNotice, isTrue);
      await controller.download();
      expect(controller.phase, UpdatePhase.ready);
      expect(installer.calls, ['verify']);
      await controller.install();
      expect(installer.calls, ['verify', 'install']);
      expect(controller.phase, UpdatePhase.installing);
    },
  );

  test('same or older builds cannot be downloaded', () async {
    installer.app = const InstalledApp(5, '0.5.0', 36, true);
    await controller.check();
    expect(controller.phase, UpdatePhase.current);
    expect(controller.hasUpdate, isFalse);
    await controller.download();
    expect(installer.calls, isEmpty);
  });

  test('native verification failure removes downloaded APK and never offers install', () async {
    installer.failVerify = true;
    await controller.check();
    await controller.download();
    expect(controller.phase, UpdatePhase.failed);
    expect(await folder.list().toList(), isEmpty);
    await controller.install();
    expect(installer.calls, ['verify']);
  });

  test('cancellation during verification cannot leave a ready installer', () async {
    installer.verifying = Completer<void>();
    await controller.check();
    final download = controller.download();
    // Wait for the fake disk write; this is a real I/O test, not a fake clock.
    while (!installer.calls.contains('verify')) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    controller.cancelDownload();
    installer.verifying!.complete();
    await download;
    expect(controller.phase, UpdatePhase.available);
    expect(await folder.list().toList(), isEmpty);
  });

  test('permission is requested explicitly and installer opens only after permission is granted', () async {
    installer.app = const InstalledApp(3, '0.3.0', 36, false);
    await controller.check();
    await controller.download();
    await controller.install();
    expect(installer.calls, ['verify', 'permission']);
    expect(controller.phase, UpdatePhase.ready);
    installer.app = const InstalledApp(3, '0.3.0', 36, true);
    await controller.resumed();
    await controller.install();
    expect(installer.calls, ['verify', 'permission', 'install']);
  });

  test('returning from installer does not claim success unless the installed code increased', () async {
    await controller.check();
    await controller.download();
    await controller.install();
    await controller.resumed();
    expect(controller.phase, UpdatePhase.ready);
    installer.app = const InstalledApp(4, '0.4.0', 36, true);
    await controller.resumed();
    expect(controller.phase, UpdatePhase.current);
    expect(controller.hasUpdate, isFalse);
  });

  test(
    'automatic checks respect the saved opt-out and manual checks still work',
    () async {
      preferences.value = const UpdatePreferences(automatic: false);
      await controller.checkAutomatically();
      expect(source.checks, 0);
      await controller.check();
      expect(source.checks, 1);
    },
  );

  test('successful automatic check is limited to once per 24 hours', () async {
    await controller.checkAutomatically();
    await controller.checkAutomatically();
    expect(source.checks, 1);
    now = now.add(const Duration(hours: 25));
    await controller.checkAutomatically();
    expect(source.checks, 2);
  });

  test('failed checks remain retryable and do not overwrite the last successful check', () async {
    source.failCheck = true;
    await controller.check();
    expect(controller.phase, UpdatePhase.failed);
    expect(preferences.value.lastCheck, isNull);
    source.failCheck = false;
    await controller.check();
    expect(controller.phase, UpdatePhase.available);
  });

  test('incompatible Android version blocks downloading', () async {
    installer.app = const InstalledApp(3, '0.3.0', 23, true);
    await controller.check();
    expect(controller.phase, UpdatePhase.incompatible);
    await controller.download();
    expect(installer.calls, isEmpty);
  });

  test('update preferences survive reopening the store', () async {
    final file = FileUpdatePreferences(() async => folder);
    final date = DateTime.utc(2026, 10, 23);
    await file.write(UpdatePreferences(automatic: false, lastCheck: date));
    final restored = await FileUpdatePreferences(() async => folder).read();
    expect(restored.automatic, isFalse);
    expect(restored.lastCheck, date);
  });
}
