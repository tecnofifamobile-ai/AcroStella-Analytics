import 'package:flutter/material.dart';

import 'capture/capture_session.dart';
import 'capture/flutter_camera_device.dart';
import 'training/training_screen.dart';

class AcroStellaApp extends StatefulWidget {
  const AcroStellaApp({super.key});

  @override
  State<AcroStellaApp> createState() => _AcroStellaAppState();
}

class _AcroStellaAppState extends State<AcroStellaApp>
    with WidgetsBindingObserver {
  late final FlutterCameraDevice _device;
  late final CaptureSession _capture;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _device = FlutterCameraDevice();
    _capture = CaptureSession(_device);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Releasing the camera when leaving the app is different from changing
    // views or reviewing a clip inside it, which must keep capture running.
    _capture.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _capture.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF66DAB5),
        brightness: brightness,
        surface: dark ? const Color(0xFF151C24) : const Color(0xFFF3F5F7),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0C1117)
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
      title: 'AcroStella Analytics',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      home: TrainingScreen(
        capture: _capture,
        device: _device,
        onToggleTheme: () => setState(() {
          _themeMode = _themeMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark;
        }),
      ),
    );
  }
}
