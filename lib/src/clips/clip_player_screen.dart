import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'clip_store.dart';
import 'exercise_details_dialog.dart';
import 'annotation_overlay.dart';
import 'video_annotation.dart';

enum ExerciseReviewResult { again }

/// File decoder only: the live camera remains owned by CaptureSession.
class ClipPlayerScreen extends StatefulWidget {
  const ClipPlayerScreen({
    required this.store,
    required this.clipId,
    this.autoplay = false,
    this.allowAnotherExercise = false,
    super.key,
  });
  final ClipStore store;
  final String clipId;
  final bool autoplay;
  final bool allowAnotherExercise;
  @override
  State<ClipPlayerScreen> createState() => _ClipPlayerScreenState();
}

class _ClipPlayerScreenState extends State<ClipPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  LocalClip? _clip;
  late final Future<void> _opening;
  Future<void>? _closing;
  bool _leased = false,
      _exitApproved = false,
      _saving = false,
      _detailsBusy = false;
  bool _playerRemoved = false;
  bool _notesFailed = false,
      _showNotes = true,
      _loop = false,
      _loopSeeking = false;
  String? _error;
  List<VideoAnnotation> _notes = [];
  final List<List<VideoAnnotation>> _undo = [], _redo = [];
  List<Offset> _draft = [];
  Duration? _draftAt, _loopA, _loopB;
  AnnotationTool? _tool;
  int _lifetime = 3, _color = 0xff66dab5;
  double _width = 0.006;
  double? _seeking;
  bool get _busy =>
      _saving || _detailsBusy || _closing != null || _playerRemoved;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _opening = _open();
  }

  Future<void> _open() async {
    try {
      _clip = await widget.store.acquire(widget.clipId);
      _leased = true;
      if (!mounted) return;
      try {
        _notes = await widget.store.annotations(widget.clipId);
      } catch (_) {
        _notesFailed = true;
      }
      if (!mounted) return;
      final controller = VideoPlayerController.file(File(_clip!.path));
      _controller = controller;
      await controller.initialize();
      controller.addListener(_repeatInterval);
      if (!mounted) return;
      setState(() {});
      if (widget.autoplay) await _perform(controller.play);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo abrir el vídeo. Vuelve a intentarlo desde la biblioteca.',
        );
      }
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<bool> _perform(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (_) {
      _message('No se pudo cambiar la reproducción. Vuelve a intentarlo.');
      return false;
    }
  }

  void _clearDraft() {
    _draft = [];
    _draftAt = null;
  }

  Future<void> _chooseTool(AnnotationTool tool) async {
    if (_busy || _notesFailed || _controller == null) return;
    if (!await _perform(_controller!.pause) || !mounted) return;
    setState(() {
      _tool = _tool == tool ? null : tool;
      _showNotes = true;
      _clearDraft();
    });
  }

  Future<bool> _saveNotes(
    List<VideoAnnotation> next, {
    bool history = true,
  }) async {
    if (_busy || _notesFailed) return false;
    setState(() => _saving = true);
    try {
      await widget.store.saveAnnotations(widget.clipId, next);
      if (!mounted) return false;
      setState(() {
        if (history) {
          _undo.add(List.of(_notes));
          if (_undo.length > 30) _undo.removeAt(0);
          _redo.clear();
        }
        _notes = List.of(next);
      });
      return true;
    } catch (_) {
      _message('No se pudo guardar el dibujo. Los anteriores se conservan.');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _clearDraft();
        });
      }
    }
  }

  Future<void> _history(bool redo) async {
    final from = redo ? _redo : _undo;
    final to = redo ? _undo : _redo;
    if (from.isEmpty || _busy) return;
    final old = List<VideoAnnotation>.of(_notes);
    final next = from.last;
    if (await _saveNotes(next, history: false) && mounted) {
      setState(() {
        from.removeLast();
        to.add(old);
      });
    }
  }

  bool get _canDraw =>
      !_busy &&
      !_notesFailed &&
      _tool != null &&
      _controller?.value.isPlaying == false &&
      _showNotes;
  void _strokeStart(Offset point) {
    if (!_canDraw) return;
    setState(() {
      _clearDraft();
      _draftAt = _controller!.value.position;
      _draft = [point];
    });
  }

  void _strokeUpdate(Offset point) {
    if (!_canDraw ||
        _draft.isEmpty ||
        _draft.length >= 512 ||
        (point - _draft.last).distance < 0.002) {
      return;
    }
    setState(() => _draft = [..._draft, point]);
  }

  Future<void> _finishDrawing() async {
    if (_notes.length >= 100) {
      _message('Máximo 100 dibujos. Borra alguno para seguir anotando.');
      if (mounted) setState(_clearDraft);
      return;
    }
    if (!_canDraw || _draftAt == null || _draft.length < 2) {
      if (mounted) setState(_clearDraft);
      return;
    }
    final duration = _controller!.value.duration;
    final start = _draftAt! > duration ? duration : _draftAt!;
    final end = _lifetime == 0
        ? duration
        : start + Duration(seconds: _lifetime);
    try {
      final note = VideoAnnotation(
        tool: _tool!,
        points: _draft,
        start: start,
        end: end > duration ? duration : end,
        color: _color,
        width: _width,
      );
      await _saveNotes([..._notes, note]);
    } on FormatException {
      if (mounted) setState(_clearDraft);
      _message('Elige puntos distintos para el dibujo.');
    }
  }

  Future<void> _point(Offset point) async {
    if (!_canDraw || _tool == AnnotationTool.freehand) return;
    _draftAt ??= _controller!.value.position;
    setState(() => _draft = [..._draft, point]);
    if (_draft.length == _tool!.pointCount) await _finishDrawing();
  }

  Future<bool> _details({bool save = false}) async {
    final clip = _clip;
    if (clip == null || _busy || _controller?.value.isInitialized != true) {
      return false;
    }
    await _perform(_controller!.pause);
    if (!mounted) return false;
    final details = await showExerciseDetails(context, clip, saving: save);
    if (details == null || !mounted) return false;
    return _updateDetails(
      saved: save ? true : null,
      name: details.name,
      memo: details.memo,
    );
  }

  Future<bool> _updateDetails({
    bool? saved,
    String? name,
    String? memo,
    bool? favorite,
    List<Duration>? markers,
  }) async {
    if (_busy) return false;
    setState(() => _detailsBusy = true);
    try {
      final clip = await widget.store.updateDetails(
        widget.clipId,
        saved: saved,
        name: name,
        memo: memo,
        favorite: favorite,
        markers: markers,
      );
      if (mounted) setState(() => _clip = clip);
      if (saved == true) _message('Ejercicio guardado en tu biblioteca.');
      return true;
    } on ClipStorageException catch (error) {
      _message(error.message);
      return false;
    } catch (_) {
      _message('No se pudieron guardar los cambios. El vídeo se conserva.');
      return false;
    } finally {
      if (mounted) setState(() => _detailsBusy = false);
    }
  }

  Future<void> _mark() async {
    if (_clip == null || _busy) return;
    final at = _controller!.value.position;
    final markers = _clip!.markers;
    if (markers.any(
      (m) => (m - at).abs() < const Duration(milliseconds: 200),
    )) {
      return;
    }
    if (markers.length >= 50) {
      _message('Máximo 50 momentos por ejercicio.');
      return;
    }
    await _updateDetails(markers: [...markers, at]..sort());
  }

  void _repeatInterval() {
    final c = _controller;
    if (!_loop ||
        _loopSeeking ||
        c == null ||
        !c.value.isPlaying ||
        _loopA == null ||
        _loopB == null ||
        c.value.position < _loopB!) {
      return;
    }
    _loopSeeking = true;
    unawaited(
      _perform(() async {
        await c.seekTo(_loopA!);
        if (mounted && _loop) await c.play();
      }).whenComplete(() => _loopSeeking = false),
    );
  }

  Future<void> _seek(Duration position, {bool relative = false}) async {
    final c = _controller!;
    await _perform(() async {
      await c.pause();
      var target = relative ? c.value.position + position : position;
      if (target.isNegative) target = Duration.zero;
      if (target > c.value.duration) target = c.value.duration;
      await c.seekTo(target);
    });
    if (mounted) {
      setState(() {
        _loop = false;
        _clearDraft();
      });
    }
  }

  Future<void> _closePlayer() => _closing ??= _opening.then((_) async {
    _controller?.removeListener(_repeatInterval);
    try {
      await _controller?.dispose();
    } finally {
      if (_leased) {
        await widget.store.release(widget.clipId);
        _leased = false;
      }
    }
  });
  Future<void> _prepareClose() async {
    if (mounted && !_playerRemoved) {
      setState(() {
        _playerRemoved = true;
        _loop = false;
        _clearDraft();
      });
      // Detach VideoPlayer/ValueListenableBuilder before disposing their source.
      await WidgetsBinding.instance.endOfFrame;
    }
    await _closePlayer();
  }

  Future<void> _leave([ExerciseReviewResult? result]) async {
    try {
      await _prepareClose();
    } catch (_) {
      _message('No se pudo cerrar el reproductor.');
      return;
    }
    if (!mounted) return;
    setState(() => _exitApproved = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _delete({
    bool confirm = true,
    ExerciseReviewResult? result,
  }) async {
    if (_busy) return;
    if (confirm) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('¿Eliminar este ejercicio?'),
          content: const Text(
            'Se eliminarán el vídeo, los dibujos y las notas de este dispositivo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() => _detailsBusy = true);
    try {
      await _prepareClose();
      await widget.store.delete(widget.clipId);
      await _leave(result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo completar la eliminación. Revisa la biblioteca e inténtalo de nuevo.';
          _exitApproved = true;
        });
      }
    } finally {
      if (mounted) setState(() => _detailsBusy = false);
    }
  }

  Future<void> _requestLeave([ExerciseReviewResult? result]) async {
    if (_busy) return;
    if (_controller?.value.isInitialized != true && _error == null) {
      // Leaving during decoder initialization keeps the pending video. Dispose
      // continues to hold its lease until native initialization/cleanup ends.
      setState(() => _exitApproved = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(result);
      return;
    }
    if (_clip?.saved != false || _error != null) {
      await _leave(result);
      return;
    }
    await _perform(_controller!.pause);
    if (!mounted) return;
    final decision = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Qué hacemos con este ejercicio?'),
        content: const Text(
          'Puedes guardarlo o eliminarlo ahora. Si decides después, quedará entre los pendientes; se conservan como máximo los 3 últimos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, 'later'),
            child: const Text('Decidir después'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, 'delete'),
            child: const Text('Eliminar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, 'save'),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (decision == 'save' && await _details(save: true)) {
      await _leave(result);
    } else if (decision == 'delete') {
      await _delete(confirm: false, result: result);
    } else if (decision == 'later') {
      await _leave(result);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _controller != null &&
        _closing == null) {
      unawaited(_perform(_controller!.pause));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      _closePlayer().catchError((Object _, StackTrace _) {
        debugPrint('No se pudo completar la limpieza del reproductor.');
      }),
    );
    super.dispose();
  }

  String _time(Duration time) =>
      '${time.inMinutes.toString().padLeft(2, '0')}:${(time.inSeconds % 60).toString().padLeft(2, '0')}.${(time.inMilliseconds % 1000 ~/ 100)}';

  Widget _annotationTools() => ExpansionTile(
    initiallyExpanded: true,
    title: const Text('Dibujar y medir'),
    tilePadding: EdgeInsets.zero,
    children: [
      Wrap(
        spacing: 4,
        children: [
          for (final tool in AnnotationTool.values)
            IconButton(
              tooltip: switch (tool) {
                AnnotationTool.line => 'Dibujar línea',
                AnnotationTool.angle => 'Medir ángulo',
                _ => tool.label,
              },
              isSelected: _tool == tool,
              onPressed: _busy || _notesFailed ? null : () => _chooseTool(tool),
              icon: Icon(switch (tool) {
                AnnotationTool.line => Icons.show_chart,
                AnnotationTool.angle => Icons.square_foot,
                AnnotationTool.freehand => Icons.gesture,
                AnnotationTool.arrow => Icons.north_east,
                AnnotationTool.rectangle => Icons.crop_square,
                AnnotationTool.ellipse => Icons.circle_outlined,
              }),
            ),
        ],
      ),
      Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final color in [0xff66dab5, 0xffffce54, 0xffff6b6b, 0xffffffff])
            IconButton(
              tooltip:
                  'Color ${switch (color) {
                    0xff66dab5 => 'menta',
                    0xffffce54 => 'amarillo',
                    0xffff6b6b => 'coral',
                    _ => 'blanco',
                  }}',
              onPressed: _busy ? null : () => setState(() => _color = color),
              icon: Icon(
                _color == color ? Icons.check_circle : Icons.circle,
                color: Color(color),
                size: 22,
              ),
            ),
          DropdownButton<int>(
            value: _lifetime,
            items: [
              for (final seconds in [1, 3, 5, 0])
                DropdownMenuItem(
                  value: seconds,
                  child: Text(
                    seconds == 0 ? 'Hasta el final' : 'Dibujo · $seconds s',
                  ),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _lifetime = value!;
                    _clearDraft();
                  }),
          ),
          DropdownButton<double>(
            value: _width,
            items: [
              for (final item in [
                (0.003, 'Fino'),
                (0.006, 'Medio'),
                (0.012, 'Grueso'),
              ])
                DropdownMenuItem(value: item.$1, child: Text(item.$2)),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _width = value!),
          ),
          IconButton(
            tooltip: 'Deshacer dibujo',
            onPressed: _busy || _undo.isEmpty ? null : () => _history(false),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Rehacer dibujo',
            onPressed: _busy || _redo.isEmpty ? null : () => _history(true),
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: 'Borrar dibujos visibles',
            onPressed:
                _busy ||
                    _notesFailed ||
                    !_notes.any((n) => n.visibleAt(_controller!.value.position))
                ? null
                : () => _saveNotes(
                    _notes
                        .where((n) => !n.visibleAt(_controller!.value.position))
                        .toList(),
                  ),
            icon: const Icon(Icons.layers_clear_outlined),
          ),
          IconButton(
            tooltip: _showNotes ? 'Ocultar dibujos' : 'Mostrar dibujos',
            onPressed: () => setState(() {
              _showNotes = !_showNotes;
              _clearDraft();
            }),
            icon: Icon(_showNotes ? Icons.visibility : Icons.visibility_off),
          ),
        ],
      ),
      if (_tool != null)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(switch (_tool!) {
            AnnotationTool.freehand =>
              'Arrastra el dedo o lápiz sobre el vídeo pausado.',
            AnnotationTool.angle =>
              'Toca extremo, vértice y extremo. Ángulo de la imagen.',
            _ => 'Toca dos puntos sobre el vídeo pausado.',
          }, textAlign: TextAlign.center),
        ),
      if (_notesFailed)
        const Text(
          'No se pudieron cargar los dibujos. El vídeo sigue disponible.',
        ),
    ],
  );

  Widget _controls(
    VideoPlayerController c,
    VideoPlayerValue value,
  ) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(_time(value.position)), Text(_time(value.duration))],
        ),
        Slider(
          min: 0,
          max: math.max(1, value.duration.inMilliseconds.toDouble()),
          value: (_seeking ?? value.position.inMilliseconds.toDouble()).clamp(
            0,
            math.max(1, value.duration.inMilliseconds.toDouble()),
          ),
          onChanged: _busy ? null : (v) => setState(() => _seeking = v),
          onChangeEnd: _busy
              ? null
              : (v) async {
                  await _seek(Duration(milliseconds: v.round()));
                  if (mounted) setState(() => _seeking = null);
                },
        ),
        Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: 'Retroceder 1 segundo',
              onPressed: () =>
                  _seek(const Duration(seconds: -1), relative: true),
              icon: const Icon(Icons.replay),
            ),
            IconButton(
              tooltip: value.isPlaying ? 'Pausar vídeo' : 'Reproducir vídeo',
              icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _busy
                  ? null
                  : () => _perform(() async {
                      if (value.isPlaying) {
                        await c.pause();
                      } else {
                        setState(() {
                          _tool = null;
                          _clearDraft();
                        });
                        if (value.position >= value.duration) {
                          await c.seekTo(Duration.zero);
                        }
                        await c.play();
                      }
                    }),
            ),
            IconButton(
              tooltip: 'Avanzar 1 segundo',
              onPressed: () =>
                  _seek(const Duration(seconds: 1), relative: true),
              icon: const Icon(Icons.fast_forward),
            ),
            DropdownButton<double>(
              value: value.playbackSpeed,
              items: [
                for (final speed in [0.25, 0.5, 1.0])
                  DropdownMenuItem(value: speed, child: Text('$speed×')),
              ],
              onChanged: (v) {
                if (v != null) unawaited(_perform(() => c.setPlaybackSpeed(v)));
              },
            ),
            TextButton.icon(
              onPressed: _busy ? null : () => _details(),
              icon: const Icon(Icons.edit_note),
              label: const Text('Nombre y notas'),
            ),
          ],
        ),
        _annotationTools(),
        ExpansionTile(
          title: const Text('Repetición y momentos'),
          tilePadding: EdgeInsets.zero,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() {
                    _loopA = value.position;
                    _loop = false;
                  }),
                  child: Text(
                    'A · ${_loopA == null ? 'Inicio' : _time(_loopA!)}',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _loopB = value.position;
                    _loop = false;
                  }),
                  child: Text(
                    'B · ${_loopB == null ? 'Final' : _time(_loopB!)}',
                  ),
                ),
                FilterChip(
                  label: const Text('Repetir A–B'),
                  selected: _loop,
                  onSelected:
                      _loopA == null ||
                          _loopB == null ||
                          _loopB! - _loopA! < const Duration(milliseconds: 300)
                      ? null
                      : (v) async {
                          if (v) await _perform(() => c.seekTo(_loopA!));
                          if (!mounted) return;
                          setState(() {
                            _loop = v;
                            _tool = null;
                            _clearDraft();
                          });
                          if (v) await _perform(c.play);
                        },
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _mark,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Marcar momento'),
                ),
              ],
            ),
            const Text(
              'A y B delimitan la repetición; el vídeo original se conserva completo.',
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final at in _clip!.markers)
                  InputChip(
                    label: Text(_time(at)),
                    onPressed: () => _seek(at),
                    onDeleted: _busy
                        ? null
                        : () => _updateDetails(
                            markers: _clip!.markers
                                .where((m) => m != at)
                                .toList(),
                          ),
                  ),
              ],
            ),
          ],
        ),
        if (_clip!.memo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_clip!.memo),
          ),
        const SizedBox(height: 12),
      ],
    ),
  );

  Widget _player(VideoPlayerController c) =>
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: c,
        builder: (context, value, _) {
          if (value.hasError) {
            return const Center(
              child: Text('No se puede reproducir este archivo.'),
            );
          }
          final video = Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoPlayer(c),
                  AnnotationOverlay(
                    notes: _showNotes ? _notes : [],
                    position: value.position,
                    videoSize: value.size,
                    draft: _draft,
                    tool: _tool,
                    color: _color,
                    width: _width,
                    onPoint: _canDraw && _tool != AnnotationTool.freehand
                        ? _point
                        : null,
                    onStrokeStart: _canDraw && _tool == AnnotationTool.freehand
                        ? _strokeStart
                        : null,
                    onStrokeUpdate: _canDraw && _tool == AnnotationTool.freehand
                        ? _strokeUpdate
                        : null,
                    onStrokeEnd: _canDraw && _tool == AnnotationTool.freehand
                        ? _finishDrawing
                        : null,
                    onStrokeCancel: _canDraw && _tool == AnnotationTool.freehand
                        ? () => setState(_clearDraft)
                        : null,
                  ),
                ],
              ),
            ),
          );
          return LayoutBuilder(
            builder: (context, box) => box.maxWidth > box.maxHeight * 1.25
                ? Row(
                    children: [
                      Expanded(flex: 3, child: video),
                      Expanded(flex: 2, child: _controls(c, value)),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(flex: 6, child: video),
                      Expanded(flex: 5, child: _controls(c, value)),
                    ],
                  ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c?.value.isInitialized == true && !_playerRemoved;
    return PopScope(
      canPop: _exitApproved || (!_busy && _clip?.saved == true),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestLeave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _clip?.name.isNotEmpty == true ? _clip!.name : 'Revisar ejercicio',
          ),
          actions: [
            if (_clip != null)
              IconButton(
                tooltip: 'Favorito',
                onPressed: _busy
                    ? null
                    : () => _updateDetails(favorite: !_clip!.favorite),
                icon: Icon(_clip!.favorite ? Icons.star : Icons.star_border),
              ),
          ],
        ),
        body: SafeArea(
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                )
              : _playerRemoved || c == null || !c.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : _player(c),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  onPressed: _busy || !ready || _clip == null || _clip!.saved
                      ? null
                      : () => _details(save: true),
                  icon: Icon(
                    _clip?.saved == true ? Icons.check : Icons.save_outlined,
                  ),
                  label: Text(
                    _clip?.saved == true ? 'Guardado' : 'Guardar ejercicio',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _busy || _clip == null || (!ready && _error == null)
                      ? null
                      : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                ),
                TextButton.icon(
                  onPressed: _busy || (!ready && _error == null)
                      ? null
                      : () => _requestLeave(
                          widget.allowAnotherExercise
                              ? ExerciseReviewResult.again
                              : null,
                        ),
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(
                    widget.allowAnotherExercise ? 'Otro ejercicio' : 'Volver',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
