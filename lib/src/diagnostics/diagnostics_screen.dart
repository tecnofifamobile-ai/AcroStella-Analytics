import 'package:flutter/material.dart';

import '../capture/capture_session.dart';
import '../connection/pair_controller.dart';
import '../remote/workspace_controller.dart';
import '../remote/remote_models.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({
    required this.capture,
    required this.pair,
    required this.workspace,
    required this.onToggleTheme,
    this.onUpdates,
    this.version,
    super.key,
  });
  final CaptureSession capture;
  final PairController pair;
  final WorkspaceController workspace;
  final VoidCallback onToggleTheme;
  final VoidCallback? onUpdates;
  final String? version;
  String _number(double? value, String suffix) =>
      value == null ? 'No disponible' : '${value.toStringAsFixed(1)} $suffix';
  String _cap(bool? value) => value == null
      ? 'No consultado'
      : value
      ? 'Disponible'
      : 'No anunciado';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([capture, pair, workspace]),
    builder: (context, _) {
      final m = workspace.metrics, c = workspace.capabilities;
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostics & Settings')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Preferencias',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.brightness_6_outlined),
                        title: const Text('Cambiar modo claro u oscuro'),
                        onTap: onToggleTheme,
                      ),
                      ListTile(
                        leading: const Icon(Icons.system_update_alt),
                        title: const Text('Actualizaciones'),
                        subtitle: Text(
                          version == null
                              ? 'Versión instalada pendiente de consultar'
                              : 'Instalada: $version',
                        ),
                        enabled: onUpdates != null,
                        onTap: onUpdates,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Estado deportivo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Cámara local'),
                        subtitle: Text(capture.status.name),
                      ),
                      ListTile(
                        title: const Text('Grabación'),
                        subtitle: Text(
                          capture.clipBusy
                              ? 'Captura o finalización en curso'
                              : 'Sin grabación activa',
                        ),
                      ),
                      ListTile(
                        title: const Text('Pareja de cámaras'),
                        subtitle: Text(pair.status),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Escritorio remoto',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Motor nativo'),
                        subtitle: Text(
                          '${c?.platform ?? 'No consultado'} · ${c?.integrated == true ? 'integrado' : 'no disponible'}',
                        ),
                      ),
                      ListTile(
                        title: const Text('Decodificación por hardware'),
                        subtitle: Text(
                          'H.264: ${_cap(c?.h264Hardware)}\nHEVC: ${_cap(c?.hevcHardware)}\nAV1: ${_cap(c?.av1Hardware)}',
                        ),
                      ),
                      ListTile(
                        title: const Text('Estado de sesión'),
                        subtitle: Text(workspace.status),
                      ),
                    ],
                  ),
                ),
                ExpansionTile(
                  title: const Text('Estadísticas avanzadas'),
                  subtitle: const Text(
                    'N/D indica que el motor no expone una medida; no equivale a cero.',
                  ),
                  children: [
                    for (final item in {
                      'FPS recibidos': _number(m.receivedFps, 'FPS'),
                      'FPS presentados': _number(m.presentedFps, 'FPS'),
                      'RTT del transporte': _number(m.networkRttMs, 'ms'),
                      'Variación del RTT': _number(m.rttVarianceMs, 'ms'),
                      'Jitter de paquetes': _number(m.jitterMs, 'ms'),
                      'Fotogramas perdidos (ventana medida)':
                          m.droppedFrames?.toString() ?? 'No disponible',
                      'Procesado en el host': _number(m.hostProcessingMs, 'ms'),
                      'Codificación': _number(m.encodeMs, 'ms'),
                      'Decodificación': _number(m.decodeMs, 'ms'),
                      'Presentación': _number(m.presentationMs, 'ms'),
                      'Bitrate real': _number(m.actualMbps, 'Mbps'),
                      'Códec activo': m.codec ?? 'No disponible',
                      'Ruta Tailscale directa/relé':
                          'No consultada; una IP 100.x no permite deducirla',
                    }.entries)
                      ListTile(
                        dense: true,
                        title: Text(item.key),
                        subtitle: Text(item.value),
                      ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'El RTT de transporte y el tiempo de consulta HTTP no son latencia completa de entrada a pantalla. La disponibilidad de hardware no demuestra que una sesión lo esté utilizando.',
                      ),
                    ),
                  ],
                ),
                ExpansionTile(
                  title: const Text('Si hay imagen pero no hay entrada'),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'En Apollo, abre el cliente AcroStella y revisa sus permisos de ratón y teclado por separado. Consulta de nuevo las aplicaciones para actualizar el diagnóstico autenticado. Comprueba el foco del teclado y libera las teclas modificadoras. No es necesario abrir puertos a Internet.',
                      ),
                    ),
                  ],
                ),
                ExpansionTile(
                  title: const Text('Perfiles y precisión'),
                  children: [
                    for (final p in RemoteProfile.presets)
                      ListTile(
                        title: Text(p.name),
                        subtitle: Text(
                          '${p.width} × ${p.height} · ${p.fps} FPS · ${p.bitrateMbps} Mbps · ${p.codec.name}',
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Configuraciones de partida para el iPad de 60 Hz. Comparar latencia requiere repetir la misma escena, resolución, red y carga del PC; no hay benchmarks físicos medidos en esta entrega.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
