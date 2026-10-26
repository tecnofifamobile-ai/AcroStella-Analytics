import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../clips/clip_library_screen.dart';
import '../clips/clip_store.dart';
import 'document_store.dart';

class MediaFilesScreen extends StatefulWidget {
  const MediaFilesScreen({
    required this.clips,
    required this.documents,
    super.key,
  });
  final ClipStore clips;
  final DocumentStore documents;
  @override
  State<MediaFilesScreen> createState() => _MediaFilesScreenState();
}

class _MediaFilesScreenState extends State<MediaFilesScreen> {
  late Future<List<PrivateDocument>> _files;
  bool _working = false;
  @override
  void initState() {
    super.initState();
    _files = widget.documents.list();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _import() async {
    setState(() => _working = true);
    try {
      final picked = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Documentos',
            extensions: [
              'pdf',
              'txt',
              'md',
              'csv',
              'docx',
              'xlsx',
              'png',
              'jpg',
              'jpeg',
            ],
            uniformTypeIdentifiers: ['public.data'],
          ),
        ],
      );
      if (picked == null) return;
      await widget.documents.importFile(picked);
      if (mounted) setState(() => _files = widget.documents.list());
    } catch (_) {
      _message(
        'No se pudo importar. El original se conserva; comprueba el espacio y el límite de 128 MiB por documento.',
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _share(PrivateDocument file) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, name: file.name)],
          fileNameOverrides: [file.name],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      _message('No se pudo abrir la hoja de compartir.');
    }
  }

  Future<void> _delete(PrivateDocument file) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Eliminar esta copia?'),
        content: Text(file.name),
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
    if (yes != true) return;
    try {
      await widget.documents.delete(file.id);
      if (mounted) setState(() => _files = widget.documents.list());
    } catch (_) {
      _message('No se pudo eliminar la copia.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Media & Files')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.video_library_outlined),
            title: const Text('Vídeos y sesiones de análisis'),
            subtitle: const Text(
              'Ambos ángulos, dibujos, momentos y copias de biblioteca',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ClipLibraryScreen(store: widget.clips),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Documentos privados',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Importar desde Archivos',
              onPressed: _working ? null : _import,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const Text(
          'Se guarda una copia en AcroStella. Compartir permite enviarla o guardarla en Archivos; no se transfiere al PC automáticamente.',
        ),
        if (_working) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        FutureBuilder<List<PrivateDocument>>(
          future: _files,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text(
                'No se pudo abrir el almacén de documentos. Los archivos no se han eliminado.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final files = snapshot.data!;
            if (files.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Icon(Icons.folder_open_outlined, size: 40),
                    const SizedBox(height: 12),
                    const Text('Todavía no has importado documentos.'),
                    TextButton.icon(
                      onPressed: _working ? null : _import,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Importar desde Archivos'),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final file in files)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(file.name),
                      subtitle: Text(
                        '${(file.bytes / 1024).toStringAsFixed(1)} KiB · Copia local',
                      ),
                      onTap: () => _share(file),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) =>
                            v == 'share' ? _share(file) : _delete(file),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'share',
                            child: Text('Compartir / guardar en Archivos'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar copia'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
