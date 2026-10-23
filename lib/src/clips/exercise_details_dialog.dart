import 'package:flutter/material.dart';

import 'clip_store.dart';

Future<({String name, String memo, String session, List<String> tags})?>
showExerciseDetails(
  BuildContext context,
  LocalClip clip, {
  bool saving = false,
}) =>
    showDialog<({String name, String memo, String session, List<String> tags})>(
      context: context,
      builder: (_) => _DetailsDialog(clip: clip, saving: saving),
    );

class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({required this.clip, required this.saving});
  final LocalClip clip;
  final bool saving;
  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  late final _name = TextEditingController(text: widget.clip.name);
  late final _session = TextEditingController(text: widget.clip.session);
  late final _tags = TextEditingController(text: widget.clip.tags.join(', '));
  late final _memo = TextEditingController(text: widget.clip.memo);
  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
    _session.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.saving ? 'Guardar ejercicio' : 'Nombre y notas'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Nombre opcional',
              hintText: 'Ej. Equilibrio · intento 3',
            ),
          ),
          if (widget.clip.id.isNotEmpty) ...[
            TextField(
              controller: _session,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Sesión de entrenamiento',
                hintText: 'Ej. Preparación del sábado',
              ),
            ),
            TextField(
              controller: _tags,
              maxLength: 262,
              decoration: const InputDecoration(
                labelText: 'Etiquetas separadas por comas',
                hintText: 'Equilibrio, trío, recepción',
              ),
            ),
          ],
          TextField(
            controller: _memo,
            maxLength: 2000,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Notas del entrenador',
            ),
          ),
          const Text(
            'Puedes organizarlo por sesión y encontrarlo por sus etiquetas.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (
          name: _name.text,
          memo: _memo.text,
          session: _session.text,
          tags: _tags.text
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .take(8)
              .map((t) => t.length > 32 ? t.substring(0, 32) : t)
              .toList(),
        )),
        child: const Text('Guardar'),
      ),
    ],
  );
}
