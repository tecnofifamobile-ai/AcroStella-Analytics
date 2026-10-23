import 'package:flutter/material.dart';

import 'clip_player_screen.dart';
import 'clip_store.dart';

class ClipLibraryScreen extends StatefulWidget {
  const ClipLibraryScreen({required this.store, super.key});

  final ClipStore store;

  @override
  State<ClipLibraryScreen> createState() => _ClipLibraryScreenState();
}

class _ClipLibraryScreenState extends State<ClipLibraryScreen> {
  late Future<List<LocalClip>> _clips;

  @override
  void initState() {
    super.initState();
    _clips = widget.store.list();
  }

  void _reload() => setState(() {
    _clips = widget.store.list();
  });

  Future<void> _delete(LocalClip clip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este clip?'),
        content: const Text('Se eliminará de este dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.store.delete(clip.id);
      if (mounted) _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo eliminar el clip. Cierra su reproductor y vuelve a intentarlo.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Clips locales'),
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: 'Actualizar clips',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Clips temporales de un ángulo · Hasta 3 clips y 128 MB.\n'
              'Al grabar más, se eliminan los más antiguos que no estén abiertos. '
              'El sistema también puede limpiar esta caché. No es la biblioteca definitiva.',
            ),
          ),
          Expanded(
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
                        'No se pudieron cargar los clips. Reintentar',
                      ),
                    ),
                  );
                }
                final clips = snapshot.data!;
                if (clips.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Todavía no hay clips. Activa la cámara y pulsa «Grabar clip».',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: clips.length,
                  itemBuilder: (context, index) {
                    final clip = clips[index];
                    final date = MaterialLocalizations.of(context)
                        .formatMediumDate(clip.createdAt.toLocal());
                    final time = TimeOfDay.fromDateTime(
                      clip.createdAt.toLocal(),
                    ).format(context);
                    return ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text('$date · $time'),
                      subtitle: Text(
                        '${(clip.bytes / (1024 * 1024)).toStringAsFixed(1)} MB · Sin audio',
                      ),
                      trailing: IconButton(
                        tooltip: 'Eliminar clip',
                        onPressed: () => _delete(clip),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      onTap: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ClipPlayerScreen(
                              store: widget.store,
                              clipId: clip.id,
                            ),
                          ),
                        );
                        if (mounted) _reload();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
