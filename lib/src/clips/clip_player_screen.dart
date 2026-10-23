import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'clip_store.dart';
import 'annotation_overlay.dart';
import 'video_annotation.dart';

/// A separate file decoder. It neither opens nor disposes the live camera.
class ClipPlayerScreen extends StatefulWidget {
  const ClipPlayerScreen({
    required this.store,
    required this.clipId,
    super.key,
  });

  final ClipStore store;
  final String clipId;

  @override
  State<ClipPlayerScreen> createState() => _ClipPlayerScreenState();
}

class _ClipPlayerScreenState extends State<ClipPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  late final Future<void> _opening;
  bool _leased = false;
  String? _error;
  double? _seeking;
  List<VideoAnnotation> _notes = [];
  List<Offset> _draft = [];
  Duration? _draftAt;
  AnnotationTool? _tool;
  int _lifetime = 3;
  bool _notesFailed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _opening = _open();
  }

  Future<void> _open() async {
    try {
      final clip = await widget.store.acquire(widget.clipId);
      _leased = true;
      if (!mounted) return;
      try {
        _notes = await widget.store.annotations(widget.clipId);
      } catch (_) {
        _notesFailed = true;
      }
      if (!mounted) return;
      final controller = VideoPlayerController.file(File(clip.path));
      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo abrir el vídeo. Puede que la caché ya no esté disponible.',
        );
      }
    }
  }

  Future<bool> _perform(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cambiar la reproducción. Vuelve a intentarlo.',
          ),
        ),
      );
      return false;
    }
  }

  void _clearDraft() {
    _draft = [];
    _draftAt = null;
  }

  Future<void> _chooseTool(AnnotationTool tool) async {
    if (_saving || _notesFailed || _controller == null) return;
    if (!await _perform(_controller!.pause) || !mounted) return;
    setState(() {
      _tool = _tool == tool ? null : tool;
      _clearDraft();
    });
  }

  Future<void> _saveNotes(List<VideoAnnotation> next) async {
    if (_saving || _notesFailed) return;
    setState(() => _saving = true);
    try {
      await widget.store.saveAnnotations(widget.clipId, next);
      if (mounted) setState(() => _notes = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar el dibujo. Los dibujos anteriores se conservan.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _clearDraft();
        });
      }
    }
  }

  Future<void> _point(Offset point) async {
    final controller = _controller;
    final tool = _tool;
    if (controller == null ||
        tool == null ||
        _saving ||
        _notesFailed ||
        controller.value.isPlaying) {
      return;
    }
    if (_notes.length >= 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Máximo 100 dibujos por clip. Puedes deshacer el último.',
          ),
        ),
      );
      return;
    }
    _draftAt ??= controller.value.position > controller.value.duration
        ? controller.value.duration
        : controller.value.position;
    final points = [..._draft, point];
    setState(() => _draft = points);
    if (points.length != (tool == AnnotationTool.line ? 2 : 3)) return;
    final finish = _draftAt! + Duration(seconds: _lifetime);
    try {
      final note = VideoAnnotation(
        tool: tool,
        points: points,
        start: _draftAt!,
        end: finish > controller.value.duration
            ? controller.value.duration
            : finish,
      );
      await _saveNotes([..._notes, note]);
    } on FormatException {
      if (!mounted) return;
      setState(() => _draft = points.sublist(0, points.length - 1));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige puntos distintos para el dibujo.')),
      );
    }
  }

  Widget _annotationTools() => Column(
    children: [
      Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            tooltip: 'Dibujar línea',
            isSelected: _tool == AnnotationTool.line,
            onPressed: _saving || _notesFailed
                ? null
                : () => _chooseTool(AnnotationTool.line),
            icon: const Icon(Icons.show_chart),
          ),
          IconButton(
            tooltip: 'Medir ángulo',
            isSelected: _tool == AnnotationTool.angle,
            onPressed: _saving || _notesFailed
                ? null
                : () => _chooseTool(AnnotationTool.angle),
            icon: const Icon(Icons.square_foot),
          ),
          DropdownButton<int>(
            value: _lifetime,
            items: [
              for (final seconds in [1, 3, 5])
                DropdownMenuItem(
                  value: seconds,
                  child: Text('Dibujo · $seconds s'),
                ),
            ],
            onChanged: _saving
                ? null
                : (seconds) => setState(() {
                    _lifetime = seconds!;
                    _clearDraft();
                  }),
          ),
          IconButton(
            tooltip: 'Deshacer dibujo',
            onPressed: _saving || _notesFailed || _notes.isEmpty
                ? null
                : () => _saveNotes(_notes.sublist(0, _notes.length - 1)),
            icon: const Icon(Icons.undo),
          ),
          if (_saving)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      if (_tool != null)
        Text(
          _tool == AnnotationTool.line
              ? 'Toca dos puntos sobre el vídeo.'
              : 'Toca extremo, vértice y extremo. Ángulo de la imagen.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      if (_notesFailed)
        const Text(
          'No se pudieron cargar los dibujos. El vídeo sigue disponible.',
        ),
    ],
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _controller != null) {
      unawaited(_perform(_controller!.pause));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Keep the file pinned through native decoder disposal, even if the route
    // is closed while acquire/initialize is still awaiting platform work.
    unawaited(
      _opening
          .then((_) async {
            try {
              await _controller?.dispose();
            } finally {
              if (_leased) await widget.store.release(widget.clipId);
            }
          })
          .catchError((Object _, StackTrace _) {
            // The route is gone; native/storage cleanup errors must not escape as
            // unhandled asynchronous UI errors. Cleanup was attempted in finally.
            debugPrint(
              'No se pudo completar la limpieza del reproductor local.',
            );
          }),
    );
    super.dispose();
  }

  String _time(Duration time) =>
      '${time.inMinutes.toString().padLeft(2, '0')}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _player(
    VideoPlayerController controller,
  ) => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      if (value.hasError) {
        return const Center(
          child: Text('No se puede reproducir este archivo.'),
        );
      }
      final duration = value.duration.inMilliseconds.toDouble();
      return Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(controller),
                    AnnotationOverlay(
                      notes: _notes,
                      position: value.position,
                      videoSize: value.size,
                      draft: _draft,
                      onPoint: _tool == null || _saving ? null : _point,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(_time(value.position)),
                Expanded(
                  child: Slider(
                    label: _time(
                      Duration(
                        milliseconds:
                            (_seeking ??
                                    value.position.inMilliseconds.toDouble())
                                .round(),
                      ),
                    ),
                    min: 0,
                    max: duration > 0 ? duration : 1,
                    value:
                        (_seeking ?? value.position.inMilliseconds.toDouble())
                            .clamp(0, duration > 0 ? duration : 1),
                    onChanged: duration > 0
                        ? (position) => setState(() => _seeking = position)
                        : null,
                    onChangeEnd: (position) async {
                      setState(_clearDraft);
                      await _perform(
                        () => controller.seekTo(
                          Duration(milliseconds: position.round()),
                        ),
                      );
                      if (mounted) setState(() => _seeking = null);
                    },
                  ),
                ),
                Text(_time(value.duration)),
              ],
            ),
          ),
          Wrap(
            spacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: value.isPlaying ? 'Pausar clip' : 'Reproducir clip',
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () => _perform(() async {
                  if (value.isPlaying) {
                    await controller.pause();
                  } else {
                    setState(() {
                      _tool = null;
                      _clearDraft();
                    });
                    if (value.position >= value.duration) {
                      await controller.seekTo(Duration.zero);
                    }
                    await controller.play();
                  }
                }),
              ),
              DropdownButton<double>(
                value: value.playbackSpeed,
                items: [
                  for (final speed in [0.25, 0.5, 1.0])
                    DropdownMenuItem(value: speed, child: Text('$speed×')),
                ],
                onChanged: (speed) {
                  if (speed != null) {
                    unawaited(
                      _perform(() => controller.setPlaybackSpeed(speed)),
                    );
                  }
                },
              ),
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Volver al directo'),
              ),
            ],
          ),
          _annotationTools(),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Clip local · Un ángulo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : _player(controller),
        ),
      ),
    );
  }
}
