import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'workspace_controller.dart';
import 'workspace_store.dart';
import 'remote_models.dart';

class RemoteWorkspaceScreen extends StatefulWidget {
  const RemoteWorkspaceScreen({required this.workspace, super.key});
  final WorkspaceController workspace;
  @override
  State<RemoteWorkspaceScreen> createState() => _RemoteWorkspaceScreenState();
}

class _RemoteWorkspaceScreenState extends State<RemoteWorkspaceScreen> {
  bool _virtual = false;
  Future<void> _add() async {
    String name = 'Mi PC', address = '';
    String? error;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setDialog) => AlertDialog(
          title: const Text('Añadir ordenador'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'IP local o dirección Tailscale',
                    hintText: '100.x.x.x o equipo.tailnet.ts.net',
                  ),
                  onChanged: (v) => address = v,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.workspace.addHost(name, address);
                  if (d.mounted) Navigator.pop(d, true);
                } catch (e) {
                  setDialog(
                    () => error = e is FormatException
                        ? e.message
                        : 'No se pudo guardar el ordenador.',
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      final host = widget.workspace.preferences.hosts.last;
      unawaited(widget.workspace.inspect(host));
    }
  }

  Future<void> _open(WorkspaceHost host, String appId) async {
    final block = widget.workspace.captureBlock;
    if (block != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(block)));
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RemoteSessionScreen(
          workspace: widget.workspace,
          host: host,
          appId: appId,
          virtualDisplay: _virtual,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.workspace,
    builder: (context, _) {
      final w = widget.workspace;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Remote Workspace'),
          actions: [
            IconButton(
              tooltip: 'Añadir ordenador',
              onPressed: w.loading || w.occupied ? null : _add,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Tu Windows, en el iPad',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(w.status),
                if (w.loading) const LinearProgressIndicator(),
                if (w.capabilities?.integrated == false)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        w.capabilities?.reason ?? 'Streaming integrado inicialmente en iPadOS. Puedes preparar equipos y perfiles desde aquí.',
                      ),
                    ),
                  ),
                if (w.pairingPin != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text('PIN de Apollo'),
                          SelectableText(
                            w.pairingPin!,
                            style: const TextStyle(
                              fontSize: 42,
                              letterSpacing: 8,
                            ),
                          ),
                          const Text(
                            'Introdúcelo en Apollo en Windows; no es el código de las cámaras.',
                          ),
                          TextButton(
                            onPressed: w.disconnect,
                            child: const Text('Cancelar emparejamiento'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Perfil de transmisión',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: w.preferences.selectedProfile,
                  items: [
                    for (final p in [
                      ...RemoteProfile.presets,
                      ...w.preferences.customProfiles,
                    ])
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: w.occupied
                      ? null
                      : (v) {
                          if (v != null) w.selectProfile(v);
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  '${w.profile.width} × ${w.profile.height} · ${w.profile.fps} FPS solicitados · ${w.profile.bitrateMbps} Mbps · ${w.profile.codec.name.toUpperCase()}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Los perfiles son ajustes de partida, no resultados medidos. La ruta directa o relé de Tailscale no se puede deducir de su dirección IP.',
                ),
                const SizedBox(height: 24),
                if (w.preferences.hosts.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.desktop_windows_outlined, size: 42),
                          const SizedBox(height: 12),
                          const Text('Añade el ordenador donde tienes Apollo.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: w.loading ? null : _add,
                            icon: const Icon(Icons.add),
                            label: const Text('Añadir ordenador'),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final host in w.preferences.hosts)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.desktop_windows),
                            title: Text(host.name),
                            subtitle: Text(host.address),
                            trailing: IconButton(
                              tooltip: 'Eliminar ordenador guardado',
                              onPressed: w.occupied
                                  ? null
                                  : () => w.removeHost(host.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                          if (w.observations[host.id] case final observation?)
                            Text(
                              '${observation.name} · ${observation.version} · consulta ${observation.queryMilliseconds} ms (no es latencia de streaming)',
                            ),
                          if (w.probeErrors[host.id] case final message?)
                            Text(message),
                          if (w.probing.contains(host.id))
                            const LinearProgressIndicator(),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: w.probing.contains(host.id)
                                    ? null
                                    : () => w.inspect(host),
                                icon: const Icon(Icons.network_check),
                                label: const Text('Comprobar conexión'),
                              ),
                              OutlinedButton(
                                onPressed:
                                    w.occupied ||
                                        w.capabilities?.integrated != true
                                    ? null
                                    : () => w.pairHost(host),
                                child: const Text('Emparejar con Apollo'),
                              ),
                              FilledButton(
                                onPressed:
                                    w.occupied ||
                                        w.capabilities?.integrated != true
                                    ? null
                                    : () => w.loadApps(host),
                                child: const Text('Consultar aplicaciones'),
                              ),
                            ],
                          ),
                          if (w.activeHostId == host.id &&
                              w.applications.isNotEmpty) ...[
                            if (w.permission != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  'Permisos anunciados: ratón ${(w.permission! & (1 << 11)) != 0 ? 'permitido' : 'denegado'} · teclado ${(w.permission! & (1 << 12)) != 0 ? 'permitido' : 'denegado'}. Se cambian en Apollo.',
                                ),
                              ),
                            if (w.virtualDisplayCapable)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Solicitar pantalla virtual'),
                                subtitle: Text(
                                  w.virtualDisplayReady
                                      ? 'Apollo informa que el controlador está preparado.'
                                      : 'Apollo no informa que el controlador esté preparado.',
                                ),
                                value: _virtual,
                                onChanged: w.virtualDisplayReady
                                    ? (v) => setState(() => _virtual = v)
                                    : null,
                              ),
                            for (final app in w.applications)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(app['name']!),
                                leading: const Icon(Icons.open_in_full),
                                trailing: const Icon(Icons.play_arrow),
                                onTap: w.occupied
                                    ? null
                                    : () => _open(host, app['id']!),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class RemoteSessionScreen extends StatefulWidget {
  const RemoteSessionScreen({
    required this.workspace,
    required this.host,
    required this.appId,
    required this.virtualDisplay,
    super.key,
  });
  final WorkspaceController workspace;
  final WorkspaceHost host;
  final String appId;
  final bool virtualDisplay;
  @override
  State<RemoteSessionScreen> createState() => _RemoteSessionScreenState();
}

class _RemoteSessionScreenState extends State<RemoteSessionScreen> {
  bool _keyboard = false, _trackpad = true, _controls = true, _stats = false;
  final _modifiers = <int>{};
  Future<void> _input(Map<String, dynamic> event) async {
    try {
      await widget.workspace.engine.input(event);
    } catch (_) {}
  }

  Future<void> _leave() async {
    await widget.workspace.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    unawaited(widget.workspace.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_leave());
    },
    child: ListenableBuilder(
      listenable: widget.workspace,
      builder: (context, _) {
        final w = widget.workspace;
        return Scaffold(
          appBar: _controls
              ? AppBar(
                  automaticallyImplyLeading: false,
                  leading: IconButton(
                    tooltip: 'Finalizar escritorio',
                    onPressed: _leave,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  title: Text(widget.host.name),
                  actions: [
                    IconButton(
                      tooltip: 'Diagnóstico en directo',
                      onPressed: () => setState(() => _stats = !_stats),
                      icon: const Icon(Icons.monitor_heart_outlined),
                    ),
                    IconButton(
                      tooltip: 'Ocultar controles',
                      onPressed: () => setState(() => _controls = false),
                      icon: const Icon(Icons.fullscreen),
                    ),
                  ],
                )
              : null,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: defaultTargetPlatform == TargetPlatform.iOS
                      ? UiKitView(
                          viewType: 'acrostella/workspace/video',
                          onPlatformViewCreated: (_) => w.connect(
                            widget.host,
                            widget.appId,
                            virtualDisplay: widget.virtualDisplay,
                          ),
                        )
                      : const Center(
                          child: Text(
                            'La superficie nativa está disponible inicialmente en iPadOS.',
                          ),
                        ),
                ),
                if (!w.connected || !w.videoAvailable)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(w.status),
                      ),
                    ),
                  ),
                if (_stats)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'FPS recibidos: ${w.metrics.receivedFps?.toStringAsFixed(1) ?? 'N/D'}\nRTT del transporte: ${w.metrics.networkRttMs?.toStringAsFixed(1) ?? 'N/D'} ms\nCódec activo: ${w.metrics.codec ?? 'N/D'}\nFPS presentados / tiempo de decodificación: N/D',
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              tooltip: _keyboard
                                  ? 'Ocultar teclado'
                                  : 'Abrir teclado',
                              onPressed: w.connected
                                  ? () async {
                                      setState(() => _keyboard = !_keyboard);
                                      await w.engine.keyboard(_keyboard);
                                    }
                                  : null,
                              icon: Icon(
                                _keyboard
                                    ? Icons.keyboard_hide
                                    : Icons.keyboard,
                              ),
                            ),
                            if (_controls) ...[
                              for (final entry in const {
                                0xA2: 'Ctrl',
                                0xA4: 'Alt',
                                0xA0: 'Shift',
                                0x5B: 'Win',
                              }.entries)
                                FilterChip(
                                  label: Text(entry.value),
                                  selected: _modifiers.contains(entry.key),
                                  onSelected: w.connected
                                      ? (selected) {
                                          setState(
                                            () => selected
                                                ? _modifiers.add(entry.key)
                                                : _modifiers.remove(entry.key),
                                          );
                                          _input({
                                            'key': entry.key,
                                            'toggle': true,
                                          });
                                        }
                                      : null,
                                ),
                              for (final entry in const {
                                0x09: 'Tab',
                                0x1B: 'Esc',
                              }.entries)
                                TextButton(
                                  onPressed: w.connected
                                      ? () => _input({'key': entry.key})
                                      : null,
                                  child: Text(entry.value),
                                ),
                              IconButton(
                                tooltip: _trackpad
                                    ? 'Cambiar a táctil directo'
                                    : 'Cambiar a trackpad',
                                onPressed: w.connected
                                    ? () {
                                        setState(() => _trackpad = !_trackpad);
                                        _input({'trackpad': _trackpad});
                                      }
                                    : null,
                                icon: Icon(
                                  _trackpad
                                      ? Icons.touch_app_outlined
                                      : Icons.mouse_outlined,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Clic derecho',
                                onPressed: w.connected
                                    ? () => _input({'right': true})
                                    : null,
                                icon: const Icon(Icons.ads_click),
                              ),
                            ],
                            IconButton(
                              tooltip: _controls
                                  ? 'Ocultar barra'
                                  : 'Mostrar controles',
                              onPressed: () =>
                                  setState(() => _controls = !_controls),
                              icon: Icon(
                                _controls
                                    ? Icons.expand_more
                                    : Icons.expand_less,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
