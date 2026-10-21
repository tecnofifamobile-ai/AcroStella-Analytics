import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../capture/capture_session.dart';
import '../capture/flutter_camera_device.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    required this.capture,
    required this.device,
    required this.onToggleTheme,
    super.key,
  });

  final CaptureSession capture;
  final FlutterCameraDevice device;
  final VoidCallback onToggleTheme;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AcroStella',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            Text(
              'ANALYTICS',
              style: TextStyle(fontSize: 10, letterSpacing: 3.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _expanded
                ? 'Mostrar ambas vistas'
                : 'Ampliar cámara local',
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.grid_view : Icons.fullscreen),
          ),
          IconButton(
            tooltip: 'Cambiar modo claro u oscuro',
            onPressed: widget.onToggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Entrenamiento · Prueba de cámara local',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final local = _CameraPanel(
                      title: 'Cámara local',
                      subtitle: 'Trasera',
                      child: ListenableBuilder(
                        listenable: widget.capture,
                        builder: (context, _) => _localView(),
                      ),
                    );
                    if (_expanded) return local;
                    final children = [
                      Expanded(child: local),
                      const SizedBox(width: 12, height: 12),
                      const Expanded(
                        child: _CameraPanel(
                          title: 'Cámara remota',
                          subtitle: 'Sin conectar',
                          child: _Message(
                            icon: Icons.videocam_off_outlined,
                            title: 'Segundo ángulo',
                            message: 'La conexión con Android todavía no está disponible en esta versión.',
                          ),
                        ),
                      ),
                    ];
                    return constraints.maxWidth >= 760
                        ? Row(children: children)
                        : Column(children: children);
                  },
                ),
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: widget.capture,
                builder: (context, _) => _controls(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _localView() {
    final capture = widget.capture;
    switch (capture.status) {
      case CaptureStatus.live:
        final controller = widget.device.controller;
        if (controller == null) return const SizedBox.shrink();
        return Center(child: CameraPreview(controller));
      case CaptureStatus.opening:
        return const Center(child: CircularProgressIndicator());
      case CaptureStatus.failed:
        return _Message(
          icon: Icons.no_photography_outlined,
          title: 'Cámara no disponible',
          message: capture.failure?.message ?? 'Vuelve a intentarlo.',
        );
      case CaptureStatus.suspended:
        return const _Message(
          icon: Icons.pause_circle_outline,
          title: 'Cámara suspendida',
          message: 'Vuelve a la aplicación para recuperar la imagen.',
        );
      case CaptureStatus.idle:
        return const _Message(
          icon: Icons.videocam_outlined,
          title: 'Tu punto de vista',
          message: 'Activa la cámara trasera para ver el entrenamiento.',
        );
    }
  }

  Widget _controls() {
    final capture = widget.capture;
    final live = capture.status == CaptureStatus.live;
    final opening = capture.status == CaptureStatus.opening;
    final format = capture.format;
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: opening
              ? null
              : () => live ? capture.stop() : capture.start(),
          icon: Icon(live ? Icons.stop_circle_outlined : Icons.videocam),
          label: Text(
            opening
                ? 'Abriendo cámara…'
                : live
                ? 'Desactivar cámara'
                : capture.status == CaptureStatus.failed
                ? 'Reintentar cámara'
                : 'Activar cámara',
          ),
        ),
        Text(
          live && format != null
              ? 'Directo · ${format.width} × ${format.height} · Sin guardar'
              : 'Sin grabación · Almacenamiento local',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CameraPanel extends StatelessWidget {
  const _CameraPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: colors.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
