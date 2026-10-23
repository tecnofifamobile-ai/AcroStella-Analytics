import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../capture/capture_session.dart';
import '../capture/flutter_camera_device.dart';
import '../clips/clip_library_screen.dart';
import '../clips/clip_player_screen.dart';
import '../updates/update_controller.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    required this.capture,
    required this.device,
    required this.onToggleTheme,
    this.updates,
    this.onOpenUpdates,
    super.key,
  });

  final CaptureSession capture;
  final FlutterCameraDevice device;
  final VoidCallback onToggleTheme;
  final UpdateController? updates;
  final VoidCallback? onOpenUpdates;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  bool _expanded = true;
  bool _reviewOpen = false;

  @override
  void initState() {
    super.initState();
    widget.capture.addListener(_reviewCompleted);
  }

  void _reviewCompleted() {
    if (!mounted ||
        _reviewOpen ||
        widget.capture.clipBusy ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.inactive ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.hidden) {
      return;
    }
    final clip = widget.capture.takeCompletedExercise();
    if (clip == null) return;
    _reviewOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final result = await Navigator.of(context).push<ExerciseReviewResult>(
          MaterialPageRoute(
            builder: (_) => ClipPlayerScreen(
              store: widget.capture.clips!,
              clipId: clip.id,
              autoplay: true,
              allowAnotherExercise: true,
            ),
          ),
        );
        if (mounted &&
            result == ExerciseReviewResult.again &&
            widget.capture.canRecord) {
          await widget.capture.startClip();
        }
      } finally {
        _reviewOpen = false;
      }
    });
  }

  @override
  void dispose() {
    widget.capture.removeListener(_reviewCompleted);
    super.dispose();
  }

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
          if (widget.updates != null)
            ListenableBuilder(
              listenable: widget.updates!,
              builder: (context, _) => IconButton(
                tooltip: 'Actualizaciones',
                onPressed: widget.onOpenUpdates,
                icon: Badge(
                  isLabelVisible: widget.updates!.hasUpdate,
                  child: const Icon(Icons.system_update_alt),
                ),
              ),
            ),
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
                  'Entrenamiento · Inicia, termina y revisa',
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
          message: 'Inicia un ejercicio o activa solo la cámara para preparar el encuadre.',
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
          onPressed: opening || capture.clipBusy
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
        if (capture.clips != null) ...[
          FilledButton.icon(
            onPressed: capture.isRecording
                ? capture.finishClip
                : capture.clipBusy || opening
                ? null
                : () async {
                    if (!live) await capture.start();
                    if (capture.canRecord) await capture.startClip();
                  },
            icon: Icon(
              capture.isRecording ? Icons.stop : Icons.fiber_manual_record,
            ),
            label: Text(switch (capture.recordingStatus) {
              ClipRecordingStatus.starting => 'Preparando ejercicio…',
              ClipRecordingStatus.finishing => 'Preparando revisión…',
              ClipRecordingStatus.recording =>
                'Terminar ejercicio · ${capture.clipElapsed.inSeconds} s',
              ClipRecordingStatus.idle => 'Iniciar ejercicio',
            }),
          ),
          OutlinedButton.icon(
            onPressed: capture.clipBusy
                ? null
                : () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ClipLibraryScreen(store: capture.clips!),
                    ),
                  ),
            icon: const Icon(Icons.video_library_outlined),
            label: const Text('Mi biblioteca'),
          ),
        ],
        Text(
          capture.isRecording
              ? 'Grabando sin audio · Límite ${capture.maxClipDuration.inSeconds} s'
              : live && format != null
              ? 'Directo · ${format.width} × ${format.height}'
              : 'Cámara desactivada · Almacenamiento local',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (capture.clipMessage != null)
          Text(
            capture.clipMessage!,
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
