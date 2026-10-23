import 'package:flutter/material.dart';

import 'clip_store.dart';

Future<({String name, String memo})?> showExerciseDetails(
  BuildContext context,
  LocalClip clip, {
  bool saving = false,
}) => showDialog<({String name, String memo})>(
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
  late final _memo = TextEditingController(text: widget.clip.memo);
  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
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
            'Se conserva en este dispositivo. La nube llegará más adelante.',
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
        onPressed: () =>
            Navigator.pop(context, (name: _name.text, memo: _memo.text)),
        child: const Text('Guardar'),
      ),
    ],
  );
}
