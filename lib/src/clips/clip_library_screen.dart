import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'exercise_backup.dart';

import 'package:flutter/material.dart';

import 'clip_player_screen.dart';
import 'clip_store.dart';
import 'exercise_details_dialog.dart';

class ClipLibraryScreen extends StatefulWidget {
  const ClipLibraryScreen({required this.store, super.key});
  final ClipStore store;
  @override
  State<ClipLibraryScreen> createState() => _ClipLibraryScreenState();
}

class _ClipLibraryScreenState extends State<ClipLibraryScreen> {
  late Future<List<LocalClip>> _clips;
  String _query = '';
  int _filter = 0;
  bool _favorites = false, _working = false, _selecting = false;
  final _selection = <String>{};
  String? _session;
  int _sort = 0;

  Future<void> _backup(bool restore) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final temp = await getTemporaryDirectory();
      if (restore) {
        final store = widget.store;
        if (store is! FileClipStore) throw StateError('Unsupported store');
        final picked = await openFile(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'Copia AcroStella',
              extensions: ['acrostella'],
              uniformTypeIdentifiers: ['public.data'],
            ),
          ],
        );
        if (picked == null) return;
        final staging = await Directory('${temp.path}/restore').createTemp();
        final count = await ExerciseBackup.restore(
          store,
          File(picked.path),
          staging,
        );
        _error('Importados $count ejercicios.');
        _reload();
      } else {
        final dir = await Directory('${temp.path}/backups')
            .create(recursive: true);
        for (final f in await dir.list().toList()) {
          if (f is File) await f.delete();
        }
        final file = await ExerciseBackup.export(
          widget.store,
          File(
            '${dir.path}/AcroStella-${DateTime.now().millisecondsSinceEpoch}.acrostella',
          ),
        );
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'Copia de AcroStella',
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      }
    } on ClipStorageException catch (e) {
      _error(e.message);
    } catch (_) {
      _error(
        'No se pudo completar la copia. Comprueba el archivo y el espacio disponible. Los ejercicios existentes se conservan.',
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _compare() async {
    if (_selection.length != 2) return;
    final ids = _selection.toList();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ClipPlayerScreen(
          store: widget.store,
          clipId: ids[0],
          comparisonClipId: ids[1],
        ),
      ),
    );
    _reload();
  }

  @override
  void initState() {
    super.initState();
    _clips = widget.store.list();
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _clips = widget.store.list();
      });
    }
  }

  void _error(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _delete(LocalClip clip) async {
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
    try {
      await widget.store.delete(clip.id);
      _reload();
    } catch (_) {
      _error(
        'No se pudo eliminar. Cierra el reproductor y vuelve a intentarlo.',
      );
    }
  }

  Future<void> _edit(LocalClip clip) async {
    final value = await showExerciseDetails(context, clip, saving: !clip.saved);
    if (value == null || !mounted) return;
    try {
      await widget.store.updateDetails(
        clip.id,
        saved: true,
        name: value.name,
        memo: value.memo,
      );
      final store = widget.store;
      if (store is OrganizedClipStore) {
        await (store as OrganizedClipStore).organize(
          clip.id,
          session: value.session,
          tags: value.tags,
        );
      }
      _reload();
    } on ClipStorageException catch (error) {
      _error(error.message);
    } catch (_) {
      _error('No se pudieron guardar los cambios.');
    }
  }

  Future<void> _favorite(LocalClip clip) async {
    try {
      await widget.store.updateDetails(clip.id, favorite: !clip.favorite);
      _reload();
    } catch (_) {
      _error('No se pudo cambiar el favorito.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mi biblioteca'),
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: 'Actualizar ejercicios',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<List<LocalClip>>(
        future: _clips,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _reload,
                child: const Text(
                  'No se pudieron cargar los ejercicios. Reintentar',
                ),
              ),
            );
          }
          final all = snapshot.data!;
          final saved = all.where((c) => c.saved).toList();
          final bytes = saved.fold(0, (n, c) => n + c.bytes);
          final matches = all
              .where(
                (c) =>
                    (_filter == 0 ? c.saved : !c.saved) &&
                    (!_favorites || c.favorite) &&
                    (_session == null || c.session == _session) &&
                    '${c.name} ${c.memo} ${c.session} ${c.tags.join(' ')}'
                        .toLowerCase()
                        .contains(_query),
              )
              .toList();
          if (_sort == 1) {
            matches.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          }
          if (_sort == 2) matches.sort((a, b) => a.name.compareTo(b.name));
          final sessions =
              all
                  .map((c) => c.session)
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => setState(() {
                              _selecting = !_selecting;
                              _selection.clear();
                            }),
                      icon: Icon(_selecting ? Icons.close : Icons.compare),
                      label: Text(
                        _selecting
                            ? 'Cancelar comparación'
                            : 'Comparar intentos',
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: !_working,
                      tooltip: 'Copias de seguridad',
                      onSelected: (v) => _backup(v == 'restore'),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'export',
                          child: Text('Exportar biblioteca'),
                        ),
                        PopupMenuItem(
                          value: 'restore',
                          child: Text('Importar copia'),
                        ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.backup_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Copias de seguridad'),
                            Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_working) const LinearProgressIndicator(),
              if (_selecting)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Selecciona dos intentos · ${_selection.length}/2',
                        ),
                      ),
                      FilledButton(
                        onPressed: _selection.length == 2 ? _compare : null,
                        child: const Text('Comparar'),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${saved.length} guardados · ${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB de 2048 MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Nombre, notas, sesión o etiquetas',
                      ),
                      onChanged: (q) =>
                          setState(() => _query = q.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('Guardados (${saved.length})'),
                          selected: _filter == 0,
                          onSelected: (_) => setState(() => _filter = 0),
                        ),
                        ChoiceChip(
                          label: Text(
                            'Pendientes (${all.length - saved.length})',
                          ),
                          selected: _filter == 1,
                          onSelected: (_) => setState(() => _filter = 1),
                        ),
                        FilterChip(
                          label: const Text('Favoritos'),
                          avatar: const Icon(Icons.star_outline, size: 18),
                          selected: _favorites,
                          onSelected: (v) => setState(() => _favorites = v),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownButton<String>(
                          value: sessions.contains(_session) ? _session : null,
                          hint: const Text('Todas las sesiones'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Todas las sesiones'),
                            ),
                            for (final session in sessions)
                              DropdownMenuItem(
                                value: session,
                                child: SizedBox(
                                  width: 160,
                                  child: Text(
                                    session,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _session = v),
                        ),
                        DropdownButton<int>(
                          value: _sort,
                          items: const [
                            DropdownMenuItem(
                              value: 0,
                              child: Text('Más recientes'),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Text('Más antiguos'),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text('Por nombre'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _sort = v!),
                        ),
                      ],
                    ),
                    if (_filter == 1)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Pendientes: se conservan los 3 últimos, hasta 512 MB. Guarda los que quieras conservar. Los guardados nunca se borran al grabar otro.',
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: matches.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            all.isEmpty
                                ? 'Inicia un ejercicio y, al terminar, guarda lo que quieras conservar.'
                                : _query.isNotEmpty || _favorites
                                ? 'No hay ejercicios con estos filtros.'
                                : _filter == 0
                                ? 'Aún no has guardado ejercicios. Revisa los pendientes.'
                                : 'No hay ejercicios pendientes.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          _reload();
                          await _clips;
                        },
                        child: ListView.builder(
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final clip = matches[index];
                            final date = MaterialLocalizations.of(context)
                                .formatMediumDate(clip.createdAt.toLocal());
                            final time = TimeOfDay.fromDateTime(
                              clip.createdAt.toLocal(),
                            ).format(context);
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: _selecting
                                    ? Checkbox(
                                        value: _selection.contains(clip.id),
                                        onChanged: (_) => setState(() {
                                          if (!_selection.remove(clip.id) &&
                                              _selection.length < 2) {
                                            _selection.add(clip.id);
                                          }
                                        }),
                                      )
                                    : Icon(
                                        clip.saved
                                            ? Icons.play_circle_outline
                                            : Icons.pending_actions,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                title: Text(
                                  clip.name.isEmpty
                                      ? 'Ejercicio · $date · $time'
                                      : clip.name,
                                ),
                                subtitle: Text(
                                  '${clip.hasSecondAngle ? 'DOS ÁNGULOS · ' : ''}$date · $time · ${(clip.bytes / (1024 * 1024)).toStringAsFixed(1)} MB${clip.markers.isEmpty ? '' : ' · ${clip.markers.length} momentos'}${clip.session.isEmpty ? '' : '\n${clip.session}'}${clip.tags.isEmpty ? '' : ' · ${clip.tags.join(' / ')}'}',
                                  maxLines: 3,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Favorito',
                                      onPressed: _working
                                          ? null
                                          : () => _favorite(clip),
                                      icon: Icon(
                                        clip.favorite
                                            ? Icons.star
                                            : Icons.star_border,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      enabled: !_working,
                                      onSelected: (value) => value == 'delete'
                                          ? _delete(clip)
                                          : _edit(clip),
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text(
                                            clip.saved
                                                ? 'Nombre y notas'
                                                : 'Guardar ejercicio',
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: _working
                                    ? null
                                    : () async {
                                        if (_selecting) {
                                          setState(() {
                                            if (!_selection.remove(clip.id) &&
                                                _selection.length < 2) {
                                              _selection.add(clip.id);
                                            }
                                          });
                                          return;
                                        }
                                        await Navigator.of(context)
                                            .push<ExerciseReviewResult>(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ClipPlayerScreen(
                                                      store: widget.store,
                                                      clipId: clip.id,
                                                      autoplay: true,
                                                    ),
                                              ),
                                            );
                                        _reload();
                                      },
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
