import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'capture/capture_session.dart';
import 'connection/pair_controller.dart';
import 'capture/flutter_camera_device.dart';
import 'clips/clip_store.dart';
import 'training/training_screen.dart';
import 'updates/update_controller.dart';
import 'updates/update_screen.dart';
import 'updates/update_source.dart';

class AcroStellaApp extends StatefulWidget {
  const AcroStellaApp({super.key});

  @override
  State<AcroStellaApp> createState() => _AcroStellaAppState();
}

class _AcroStellaAppState extends State<AcroStellaApp>
    with WidgetsBindingObserver {
  late final FlutterCameraDevice _device;
  late final CaptureSession _capture;
  late final PairController _pair;
  ThemeMode _themeMode = ThemeMode.dark;
  UpdateController? _updates;
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  int? _notifiedVersion;

  @override
  void initState() {
    super.initState();
    _device = FlutterCameraDevice();
    _capture = CaptureSession(
      _device,
      maxClipDuration: const Duration(minutes: 3),
      clips: FileClipStore(
        () async {
          final support = await getApplicationSupportDirectory();
          return Directory('${support.path}/acrostella_exercises_v1');
        },
        maxBytes: 512 * 1024 * 1024,
        maxClipBytes: 256 * 1024 * 1024,
        durable: true,
        legacyDirectory: () async => Directory(
          '${(await getTemporaryDirectory()).path}/acrostella_local_clips_v1',
        ),
      ),
    );
    _pair = PairController(
      _capture,
      () async =>
          Directory('${(await getTemporaryDirectory()).path}/paired_transfer'),
    );
    if (Platform.isAndroid) {
      _updates = UpdateController(
        source: GitHubUpdateSource(),
        installer: AndroidUpdateInstaller(),
        preferences: FileUpdatePreferences(
          () async => getApplicationSupportDirectory(),
        ),
        downloadDirectory: () async =>
            Directory('${(await getTemporaryDirectory()).path}/app_updates'),
      )..addListener(_onUpdateChanged);
      _capture.addListener(_onCaptureChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onCaptureChanged();
      });
    }
    WidgetsBinding.instance.addObserver(this);
  }

  void _onCaptureChanged() {
    if (_capture.status == CaptureStatus.idle) {
      unawaited(_updates?.checkAutomatically());
    }
    _onUpdateChanged();
  }

  void _openUpdates() {
    final updates = _updates;
    if (updates == null) return;
    _navigator.currentState?.push<void>(
      MaterialPageRoute(
        builder: (_) => UpdateScreen(updates: updates, capture: _capture),
      ),
    );
  }

  void _onUpdateChanged() {
    final updates = _updates;
    if (!mounted ||
        updates == null ||
        !updates.showNotice ||
        _capture.clipBusy ||
        _notifiedVersion == updates.release!.versionCode) {
      return;
    }
    _notifiedVersion = updates.release!.versionCode;
    _messenger.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
        content: Text(
          'AcroStella ${updates.release!.versionName} está disponible',
        ),
        action: SnackBarAction(label: 'Ver', onPressed: _openUpdates),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Releasing the camera when leaving the app is different from changing
    // views or reviewing a clip inside it, which must keep capture running.
    _capture.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_pair.disconnect());
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_updates?.resumed());
      _onCaptureChanged();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _capture.removeListener(_onCaptureChanged);
    _updates?.removeListener(_onUpdateChanged);
    _updates?.dispose();
    _pair.dispose();
    _capture.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF66DAB5),
        brightness: brightness,
        surface: dark ? const Color(0xFF17212C) : const Color(0xFFF3F5F7),
      ),
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1C2935) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF17212C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0B1119)
          : const Color(0xFFE8EDF2),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      scaffoldMessengerKey: _messenger,
      title: 'AcroStella Analytics',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      home: TrainingScreen(
        capture: _capture,
        pair: _pair,
        device: _device,
        updates: _updates,
        onOpenUpdates: _openUpdates,
        onToggleTheme: () => setState(() {
          _themeMode = _themeMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark;
        }),
      ),
    );
  }
}
