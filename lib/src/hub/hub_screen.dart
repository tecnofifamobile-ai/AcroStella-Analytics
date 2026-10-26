import 'dart:async';

import 'package:flutter/material.dart';

import '../capture/capture_session.dart';
import '../capture/flutter_camera_device.dart';
import '../clips/clip_store.dart';
import '../clips/clip_player_screen.dart';
import '../training/training_screen.dart';
import '../connection/pair_controller.dart';
import '../remote/workspace_controller.dart';
import '../remote/remote_screen.dart';
import '../files/document_store.dart';
import '../files/media_files_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../updates/update_controller.dart';
import 'device_center_screen.dart';
import 'module_activity.dart';

enum HubArea { home, analytics, remote, devices, files, settings }

class AcroStellaHub extends StatefulWidget {
  const AcroStellaHub({
    required this.capture,
    required this.device,
    required this.pair,
    required this.workspace,
    required this.documents,
    required this.onToggleTheme,
    this.updates,
    this.onUpdates,
    this.version,
    super.key,
  });
  final CaptureSession capture;
  final FlutterCameraDevice device;
  final PairController pair;
  final WorkspaceController workspace;
  final DocumentStore documents;
  final VoidCallback onToggleTheme;
  final VoidCallback? onUpdates;
  final UpdateController? updates;
  final String? version;
  @override
  State<AcroStellaHub> createState() => _AcroStellaHubState();
}

class _AcroStellaHubState extends State<AcroStellaHub> {
  HubArea _selected = HubArea.home;
  final _visited = <HubArea>{HubArea.home};
  final _navigators = {
    for (final area in HubArea.values) area: GlobalKey<NavigatorState>(),
  };
  late Future<List<LocalClip>> _library;
  bool _switching = false;
  static const _titles = [
    'Hub',
    'Analytics',
    'Workspace',
    'Dispositivos',
    'Archivos',
    'Ajustes',
  ];
  static const _icons = [
    Icons.space_dashboard_outlined,
    Icons.video_camera_back_outlined,
    Icons.desktop_windows_outlined,
    Icons.devices_other_outlined,
    Icons.folder_outlined,
    Icons.tune,
  ];
  @override
  void initState() {
    super.initState();
    _library = _readLibrary();
  }

  Future<List<LocalClip>> _readLibrary() async {
    final clips = [...await widget.capture.clips!.list()];
    clips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return clips;
  }

  Future<void> _select(HubArea area) async {
    if (area == _selected || _switching) return;
    _switching = true;
    try {
      if (_selected == HubArea.remote && widget.workspace.occupied) {
        await widget.workspace.disconnect();
      }
      if (!mounted) return;
      if (widget.workspace.occupied && area == HubArea.analytics) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se ha confirmado el cierre del escritorio. Reintenta finalizarlo antes de activar la cámara.',
            ),
          ),
        );
        return;
      }
      setState(() {
        _selected = area;
        _visited.add(area);
        if (area == HubArea.home) _library = _readLibrary();
      });
    } finally {
      _switching = false;
    }
  }

  Future<void> _back() async {
    final navigator = _navigators[_selected]!.currentState;
    if (navigator != null && await navigator.maybePop()) return;
    await _select(HubArea.home);
  }

  Future<void> _record() async {
    await _select(HubArea.analytics);
    if (!mounted ||
        _selected != HubArea.analytics ||
        widget.workspace.occupied) {
      return;
    }
    final capture = widget.capture, pair = widget.pair;
    if (capture.clipBusy ||
        pair.busy ||
        pair.satellite ||
        pair.transferPending) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (pair.connected) {
      await pair.startExercise();
    } else {
      await capture.start();
      if (capture.canRecord) await capture.startClip();
    }
  }

  Future<void> _last(LocalClip clip) async {
    await _select(HubArea.analytics);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _selected != HubArea.analytics) return;
    await _navigators[HubArea.analytics]!.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ClipPlayerScreen(store: widget.capture.clips!, clipId: clip.id),
      ),
    );
  }

  Widget _module(HubArea area) => switch (area) {
    HubArea.home => _dashboard(),
    HubArea.analytics => TrainingScreen(
      capture: widget.capture,
      device: widget.device,
      pair: widget.pair,
      active: _selected == HubArea.analytics,
      updates: widget.updates,
      installedVersion: widget.version,
      onOpenUpdates: widget.onUpdates,
      onToggleTheme: widget.onToggleTheme,
    ),
    HubArea.remote => RemoteWorkspaceScreen(workspace: widget.workspace),
    HubArea.devices => DeviceCenterScreen(
      capture: widget.capture,
      pair: widget.pair,
      workspace: widget.workspace,
      version: widget.version,
    ),
    HubArea.files => MediaFilesScreen(
      clips: widget.capture.clips!,
      documents: widget.documents,
    ),
    HubArea.settings => DiagnosticsScreen(
      capture: widget.capture,
      pair: widget.pair,
      workspace: widget.workspace,
      onToggleTheme: widget.onToggleTheme,
      onUpdates: widget.onUpdates,
      version: widget.version,
    ),
  };
  Widget _dashboard() => ListenableBuilder(
    listenable: Listenable.merge([
      widget.capture,
      widget.pair,
      widget.workspace,
    ]),
    builder: (context, _) {
      final capture = widget.capture,
          pair = widget.pair,
          workspace = widget.workspace;
      return Scaffold(
        appBar: AppBar(
          title: const Text('AcroStella Analytics'),
          actions: [
            IconButton(
              tooltip: 'Cambiar modo claro u oscuro',
              onPressed: widget.onToggleTheme,
              icon: const Icon(Icons.brightness_6_outlined),
            ),
            IconButton(
              tooltip: 'Diagnóstico y ajustes',
              onPressed: () => _select(HubArea.settings),
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'AcroStella Hub',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Entrenamiento, dispositivos y tu espacio de trabajo.',
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Chip(
                        avatar: Icon(
                          capture.clipBusy
                              ? Icons.fiber_manual_record
                              : Icons.videocam_outlined,
                          size: 18,
                        ),
                        label: Text(
                          capture.clipBusy
                              ? 'Grabación / finalización activa'
                              : capture.status == CaptureStatus.live
                              ? 'Cámara local activa'
                              : 'Cámara local en reposo',
                        ),
                      ),
                      Chip(
                        avatar: Icon(
                          pair.connected ? Icons.link : Icons.link_off,
                          size: 18,
                        ),
                        label: Text(
                          pair.connected
                              ? 'Segunda cámara conectada'
                              : 'Sin segunda cámara conectada',
                        ),
                      ),
                      Chip(
                        avatar: const Icon(
                          Icons.desktop_windows_outlined,
                          size: 18,
                        ),
                        label: Text(
                          workspace.connected
                              ? 'Escritorio conectado'
                              : 'Sin escritorio activo',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _switching || capture.clipBusy || pair.busy
                            ? null
                            : _record,
                        icon: const Icon(Icons.fiber_manual_record),
                        label: const Text('Nueva grabación'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _select(HubArea.remote),
                        icon: const Icon(Icons.desktop_windows),
                        label: const Text('Conectar al PC'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _select(HubArea.files),
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Archivos y biblioteca'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  LayoutBuilder(
                    builder: (context, bounds) {
                      final columns = bounds.maxWidth >= 1050
                          ? 3
                          : bounds.maxWidth >= 650
                          ? 2
                          : 1;
                      final width =
                          (bounds.maxWidth - (columns - 1) * 16) / columns;
                      final cards = [
                        (
                          HubArea.analytics,
                          'Acro Analytics',
                          'Captura, dos ángulos y análisis técnico',
                          Icons.video_camera_back_outlined,
                        ),
                        (
                          HubArea.remote,
                          'Remote Workspace',
                          'Tu Windows con Apollo y controles nativos',
                          Icons.desktop_windows_outlined,
                        ),
                        (
                          HubArea.devices,
                          'Device Center',
                          'Conexiones y estado real de tus equipos',
                          Icons.devices_other_outlined,
                        ),
                        (
                          HubArea.files,
                          'Media & Files',
                          'Vídeos, sesiones y documentos privados',
                          Icons.folder_outlined,
                        ),
                        (
                          HubArea.settings,
                          'Diagnostics & Settings',
                          'Perfiles, capacidades y diagnóstico',
                          Icons.tune,
                        ),
                      ];
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final card in cards)
                            SizedBox(
                              width: width,
                              child: Card(
                                margin: EdgeInsets.zero,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _select(card.$1),
                                  child: Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          card.$4,
                                          size: 30,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          card.$2,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(card.$3),
                                        const SizedBox(height: 12),
                                        const Align(
                                          alignment: Alignment.centerRight,
                                          child: Icon(Icons.arrow_forward),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  FutureBuilder<List<LocalClip>>(
                    future: _library,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text(
                          'No se pudo consultar la biblioteca; no se han eliminado archivos.',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final clips = snapshot.data!;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(
                            clips.isEmpty
                                ? 'Todavía no hay análisis guardados'
                                : 'Último ejercicio disponible',
                          ),
                          subtitle: clips.isEmpty
                              ? const Text(
                                  'Inicia una grabación para preparar tu primera revisión.',
                                )
                              : Text(
                                  '${clips.first.name.isEmpty ? 'Ejercicio sin nombre' : clips.first.name} · ${clips.first.hasSecondAngle ? 'Dos ángulos' : 'Un ángulo'}',
                                ),
                          trailing: clips.isEmpty
                              ? null
                              : const Icon(Icons.chevron_right),
                          onTap: clips.isEmpty
                              ? null
                              : () => _last(clips.first),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide = bounds.maxWidth >= 1000;
      return PopScope(
        canPop: _selected == HubArea.home,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_back());
        },
        child: Scaffold(
          body: Row(
            children: [
              if (wide)
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: _selected.index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (index) =>
                        _select(HubArea.values[index]),
                    destinations: [
                      for (final area in HubArea.values)
                        NavigationRailDestination(
                          icon: Icon(_icons[area.index]),
                          label: Text(_titles[area.index]),
                        ),
                    ],
                  ),
                ),
              if (wide) const VerticalDivider(width: 1),
              Expanded(
                child: IndexedStack(
                  index: _selected.index,
                  children: [
                    for (final area in HubArea.values)
                      _visited.contains(area)
                          ? ModuleActivity(
                              active: _selected == area,
                              child: Navigator(
                                key: _navigators[area],
                                pages: [
                                  MaterialPage(
                                    key: ValueKey(area),
                                    child: _module(area),
                                  ),
                                ],
                                onDidRemovePage: (_) {},
                              ),
                            )
                          : const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : SafeArea(
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        for (final area in HubArea.values)
                          Expanded(
                            child: Tooltip(
                              message: _titles[area.index],
                              child: InkWell(
                                onTap: () => _select(area),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _icons[area.index],
                                      color: area == _selected
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                          : null,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _titles[area.index],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: area == _selected
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      );
    },
  );
}
