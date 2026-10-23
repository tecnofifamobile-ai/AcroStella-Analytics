import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pair_controller.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({required this.pair, super.key});
  final PairController pair;
  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _link = TextEditingController();
  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dispositivos')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.pair,
        builder: (context, _) {
          final pair = widget.pair;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Icon(
                    pair.connected ? Icons.link : Icons.devices,
                    size: 52,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    pair.connected
                        ? 'Dos perspectivas. Un ejercicio.'
                        : 'Tu estudio, conectado.',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(pair.status, textAlign: TextAlign.center),
                  if (pair.busy)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: LinearProgressIndicator(
                        value: pair.progress > 0 ? pair.progress : null,
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (!pair.connected && !pair.hosting) ...[
                    const Text(
                      '1 · En el Android',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: pair.busy ? null : pair.host,
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Usar como segunda cámara'),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '2 · En el iPad',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _link,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Enlace de emparejamiento',
                        hintText: 'acrostella://192.168…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: pair.busy ? null : () => pair.join(_link.text),
                      icon: const Icon(Icons.link),
                      label: const Text('Conectar con Android'),
                    ),
                  ],
                  if (pair.invitation != null) ...[
                    const Text(
                      'Copia o escribe en el iPad uno de estos enlaces. Si usas hotspot, elige la dirección de esa red.',
                    ),
                    const SizedBox(height: 12),
                    for (final link in pair.invitations)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(link),
                              TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: link),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Copiar enlace'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  if (pair.connected && !pair.satellite) ...[
                    if (pair.estimate != null)
                      Text(
                        'Intercambio de reloj: ida y vuelta ${(pair.estimate!.roundTripUs / 1000).toStringAsFixed(1)} ms. La alineación del movimiento se comprueba durante la revisión.',
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Vuelve a Captura para iniciar y terminar ambos ángulos desde el iPad. Al terminar, espera la transferencia del vídeo antes de revisar los dos juntos.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed:
                          !pair.transferPending || pair.busy || pair.recording
                          ? null
                          : pair.finishExercise,
                      child: const Text('Reintentar transferencia pendiente'),
                    ),
                  ],
                  if (pair.transferPending)
                    TextButton(
                      onPressed: pair.busy ? null : pair.keepLocal,
                      child: const Text('Continuar con el vídeo local'),
                    ),
                  if (pair.connected || pair.hosting)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: TextButton(
                        onPressed: pair.busy || pair.recording
                            ? null
                            : pair.disconnect,
                        child: const Text('Desconectar'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Mantén ambas apps abiertas y las pantallas desbloqueadas. Los vídeos viajan cifrados por tu red local. No se usa una cuenta ni una nube. Esta entrega transfiere el archivo al terminar; no muestra vídeo remoto en directo.',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
