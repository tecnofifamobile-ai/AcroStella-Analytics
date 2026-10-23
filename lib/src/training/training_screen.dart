import 'package:flutter/material.dart';

import '../capture/capture_session.dart';
import '../capture/flutter_camera_device.dart';
import '../clips/clip_library_screen.dart';
import '../clips/clip_player_screen.dart';
import '../updates/update_controller.dart';
import '../connection/pair_controller.dart';
import '../connection/connection_screen.dart';
import '../design/studio_glass.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    required this.capture,
    required this.device,
    required this.onToggleTheme,
    this.updates,
    this.pair,
    this.installedVersion,
    this.onOpenUpdates,
    super.key,
  });

  final CaptureSession capture;
  final FlutterCameraDevice device;
  final VoidCallback onToggleTheme;
  final UpdateController? updates;
  final PairController? pair;
  final String? installedVersion;
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
    widget.pair?.addListener(_reviewCompleted);
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
    final pair = widget.pair;
    final paired = pair?.takeCompleted();
    if (paired == null && pair?.managesCapture == true) return;
    final clip = paired ?? widget.capture.takeCompletedExercise();
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
          if (widget.pair?.connected == true) {
            await widget.pair!.startExercise();
          } else {
            await widget.capture.startClip();
          }
        }
      } finally {
        _reviewOpen = false;
      }
    });
  }

  @override
  void dispose() {
    widget.capture.removeListener(_reviewCompleted);
    widget.pair?.removeListener(_reviewCompleted);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.capture,
        widget.pair,
        widget.pair?.preview,
      ]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AcroStella',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              Text(
                widget.installedVersion == null
                    ? 'ANALYTICS'
                    : 'v${widget.installedVersion}',
                style: const TextStyle(fontSize: 10, letterSpacing: 1.2),
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
              tooltip:
                  _expanded &&
                      (widget.pair?.connected != true ||
                          widget.pair?.satellite == true)
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
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        'ESTUDIO',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              letterSpacing: 2.8,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (widget.pair != null)
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => ConnectionScreen(
                                pair: widget.pair!,
                                installedVersion: widget.installedVersion,
                              ),
                            ),
                          ),
                          icon: Icon(
                            widget.pair!.connected ? Icons.link : Icons.devices,
                          ),
                          label: Text(
                            widget.pair!.connected
                                ? 'Dispositivos · conectados'
                                : 'Dispositivos',
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final local = _CameraPanel(
                        title: 'Cámara local',
                        subtitle: widget.capture.isRecording
                            ? '● REC'
                            : '01 · Este dispositivo',
                        child: ListenableBuilder(
                          listenable: widget.capture,
                          builder: (context, _) => _localView(),
                        ),
                      );
                      if (_expanded &&
                          (widget.pair?.connected != true ||
                              widget.pair?.satellite == true)) {
                        return local;
                      }
                      final children = [
                        Expanded(child: local),
                        const SizedBox(width: 12, height: 12),
                        Expanded(
                          child: _CameraPanel(
                            title: 'Cámara remota',
                            subtitle: widget.pair?.connected == true
                                ? 'Conectada'
                                : 'Sin conectar',
                            child: widget.pair?.preview?.ready == true
                                ? widget.pair!.preview!.view()
                                : Center(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.linked_camera_outlined,
                                            size: 32,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            widget.pair?.connected == true
                                                ? widget
                                                          .pair
                                                          ?.preview
                                                          ?.status ??
                                                      'Directo no disponible'
                                                : 'Conecta la segunda cámara desde Dispositivos.',
                                            textAlign: TextAlign.center,
                                          ),
                                          if (widget.pair?.connected == true &&
                                              widget.pair?.satellite == false)
                                            TextButton.icon(
                                              onPressed:
                                                  widget.pair!.retryPreview,
                                              icon: const Icon(Icons.refresh),
                                              label: const Text(
                                                'Reintentar vídeo',
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ];
                      return constraints.maxWidth >= 600 &&
                              constraints.maxWidth > constraints.maxHeight
                          ? Row(children: children)
                          : Column(children: children);
                    },
                  ),
                ),
                if (widget.pair != null &&
                    (widget.pair!.connected ||
                        widget.pair!.hosting ||
                        widget.pair!.busy))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.pair!.status,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (widget.pair!.busy)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: LinearProgressIndicator(
                              value: widget.pair!.progress > 0
                                  ? widget.pair!.progress
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (widget.pair?.transferPending == true &&
                    widget.pair?.busy == false)
                  TextButton.icon(
                    onPressed: widget.pair?.connected == true
                        ? widget.pair!.finishExercise
                        : null,
                    icon: const Icon(Icons.sync),
                    label: const Text('Recuperar segundo ángulo pendiente'),
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
      ),
    );
  }

  Widget _localView() {
    final capture = widget.capture;
    switch (capture.status) {
      case CaptureStatus.live:
        return Center(child: widget.device.preview());
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
    final pair = widget.pair;
    final paired = pair?.connected == true && pair?.satellite == false;
    final blocked =
        pair?.busy == true ||
        pair?.satellite == true ||
        pair?.transferPending == true;
    final main = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: capture.isRecording
            ? const Color(0xFFCE4054)
            : Theme.of(context).colorScheme.primary,
        minimumSize: const Size(56, 54),
      ),
      onPressed: blocked
          ? null
          : capture.isRecording
          ? (paired ? pair!.finishExercise : capture.finishClip)
          : capture.clipBusy || opening
          ? null
          : () async {
              if (paired) {
                await pair!.startExercise();
                return;
              }
              if (!live) await capture.start();
              if (capture.canRecord) await capture.startClip();
            },
      icon: Icon(
        capture.isRecording ? Icons.stop_rounded : Icons.fiber_manual_record,
        size: 22,
      ),
      label: Text(switch (capture.recordingStatus) {
        ClipRecordingStatus.starting => 'Preparando…',
        ClipRecordingStatus.finishing => 'Preparando revisión…',
        ClipRecordingStatus.recording =>
          'Revisar · ${capture.clipElapsed.inSeconds} s',
        ClipRecordingStatus.idle =>
          paired ? 'Iniciar · dos ángulos' : 'Iniciar ejercicio',
      }),
    );
    final camera = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: blocked || paired || opening || capture.clipBusy
          ? null
          : () => live ? capture.stop() : capture.start(),
      icon: Icon(live ? Icons.videocam_rounded : Icons.videocam_outlined),
      label: Text(
        opening
            ? 'Abriendo…'
            : live
            ? 'Cámara activa'
            : 'Activar cámara',
      ),
    );
    final library = IconButton.filledTonal(
      tooltip: 'Mi biblioteca',
      onPressed: capture.clipBusy || pair?.busy == true
          ? null
          : () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ClipLibraryScreen(store: capture.clips!),
              ),
            ),
      icon: const Icon(Icons.video_library_outlined),
    );
    return StudioGlass(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final compact = MediaQuery.sizeOf(context).height < 500;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bounds.maxWidth < 500 && !compact) ...[
                  if (capture.clips != null)
                    SizedBox(width: double.infinity, child: main),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: camera,
                        ),
                      ),
                      if (capture.clips != null) library,
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      camera,
                      const SizedBox(width: 8),
                      if (capture.clips != null) ...[
                        Expanded(child: main),
                        const SizedBox(width: 8),
                        library,
                      ],
                    ],
                  ),
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      capture.clipMessage ??
                          (capture.isRecording
                              ? '${paired ? 'Dos ángulos' : 'Un ángulo'} · Sin audio · Máx. ${capture.maxClipDuration.inMinutes} min'
                              : live && format != null
                              ? 'Directo · ${format.width} × ${format.height} · Pantalla despierta'
                              : 'Grabaciones privadas en este dispositivo'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
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
