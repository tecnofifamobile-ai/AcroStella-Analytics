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
  bool _favorites = false;
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
                    '${c.name} ${c.memo}'.toLowerCase().contains(_query),
              )
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        hintText: 'Buscar por nombre o notas',
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
                                leading: Icon(
                                  clip.saved
                                      ? Icons.play_circle_outline
                                      : Icons.pending_actions,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(
                                  clip.name.isEmpty
                                      ? 'Ejercicio · $date · $time'
                                      : clip.name,
                                ),
                                subtitle: Text(
                                  '$date · $time · ${(clip.bytes / (1024 * 1024)).toStringAsFixed(1)} MB${clip.markers.isEmpty ? '' : ' · ${clip.markers.length} momentos'}',
                                  maxLines: 2,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Favorito',
                                      onPressed: () => _favorite(clip),
                                      icon: Icon(
                                        clip.favorite
                                            ? Icons.star
                                            : Icons.star_border,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
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
                                onTap: () async {
                                  await Navigator.of(context)
                                      .push<ExerciseReviewResult>(
                                        MaterialPageRoute(
                                          builder: (_) => ClipPlayerScreen(
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
