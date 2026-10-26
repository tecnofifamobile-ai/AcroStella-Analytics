import 'package:flutter/material.dart';

import '../capture/capture_session.dart';
import '../connection/pair_controller.dart';
import '../connection/connection_screen.dart';
import '../remote/workspace_controller.dart';

class DeviceCenterScreen extends StatelessWidget {
  const DeviceCenterScreen({
    required this.capture,
    required this.pair,
    required this.workspace,
    this.version,
    super.key,
  });
  final CaptureSession capture;
  final PairController pair;
  final WorkspaceController workspace;
  final String? version;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([capture, pair, workspace]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Device Center')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.tablet_mac_outlined),
                  title: const Text('Este dispositivo'),
                  subtitle: Text(
                    'Cámara: ${capture.status.name}\n${capture.clipBusy ? 'Grabación / finalización activa' : 'Sin grabación activa'}\nBatería: no consultada',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Cámaras del entrenamiento',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        pair.connected ? Icons.link : Icons.link_off,
                      ),
                      title: Text(
                        pair.connected
                            ? 'Pareja conectada'
                            : 'Sin pareja conectada',
                      ),
                      subtitle: Text(pair.status),
                    ),
                    if (pair.preview != null)
                      ListTile(
                        title: const Text('Vista remota'),
                        subtitle: Text(pair.preview!.status),
                      ),
                    ListTile(
                      leading: const Icon(Icons.settings_input_antenna),
                      title: const Text('Conectar y gestionar cámaras'),
                      subtitle: Text(
                        '${pair.trusted.length} dispositivos recordados',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => ConnectionScreen(
                            pair: pair,
                            installedVersion: version,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Ordenadores guardados',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (workspace.preferences.hosts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Añade tu PC desde Remote Workspace.'),
                ),
              for (final host in workspace.preferences.hosts)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.desktop_windows_outlined),
                    title: Text(host.name),
                    subtitle: Text(
                      '${host.address}\n${workspace.observations[host.id] != null ? 'Respondió en la última consulta manual' : workspace.probeErrors[host.id] ?? 'Sin comprobar'}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Comprobar ordenador',
                      onPressed: workspace.probing.contains(host.id)
                          ? null
                          : () => workspace.inspect(host),
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'No se sondea toda la red ni se inventa un router o nivel de batería remoto. La lista muestra únicamente las cámaras de la sesión y los equipos que guardes.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
