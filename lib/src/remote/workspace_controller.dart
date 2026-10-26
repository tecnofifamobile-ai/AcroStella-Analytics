import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../capture/capture_session.dart';
import '../connection/pair_controller.dart';
import 'apollo_probe.dart';
import 'remote_models.dart';
import 'workspace_engine.dart';
import 'workspace_store.dart';

enum WorkspaceState { idle, pairing, connecting, connected, disconnecting }

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required this.store,
    required this.engine,
    required this.capture,
    required this.pair,
    ApolloProbe? probe,
  }) : probe = probe ?? ApolloProbe();
  final WorkspaceStore store;
  final WorkspaceEngine engine;
  final CaptureSession capture;
  final PairController pair;
  final ApolloProbe probe;
  WorkspacePreferences preferences = const WorkspacePreferences();
  WorkspaceCapabilities? capabilities;
  final Map<String, ApolloObservation> observations = {};
  final Map<String, String> probeErrors = {};
  final Set<String> probing = {};
  WorkspaceState state = WorkspaceState.idle;
  RemoteMetrics metrics = const RemoteMetrics();
  String status = 'Añade tu PC con su dirección local o Tailscale.';
  String? pairingPin, activeHostId;
  List<Map<String, String>> applications = [];
  int? permission;
  bool virtualDisplayCapable = false, virtualDisplayReady = false;
  bool loading = true, _disposed = false, _restoreCamera = false;
  int _generation = 0;
  StreamSubscription<Map<String, dynamic>>? _events;
  bool get occupied => state != WorkspaceState.idle;
  bool get connected => state == WorkspaceState.connected;
  bool get captureProtected =>
      capture.clipBusy ||
      pair.recording ||
      pair.busy ||
      pair.transferPending ||
      pair.connected ||
      pair.hosting;
  String? get captureBlock => captureProtected
      ? 'Acro Analytics tiene una captura, transferencia o cámara emparejada. Finaliza la operación y desconecta la pareja desde Device Center antes de iniciar el escritorio.'
      : null;
  RemoteProfile get profile =>
      [...RemoteProfile.presets, ...preferences.customProfiles].firstWhere(
        (p) => p.id == preferences.selectedProfile,
        orElse: () => RemoteProfile.presets.first,
      );
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    try {
      preferences = await store.read();
      capabilities = await engine.capabilities();
      if (capabilities!.integrated) {
        _events = engine.events.listen(
          _event,
          onError: (Object error) {
            status = 'El adaptador nativo dejó de responder.';
            unawaited(disconnect());
          },
        );
      }
    } catch (_) {
      status = 'No se pudo leer la configuración. No se sobrescribirá automáticamente.';
    }
    loading = false;
    _notify();
  }

  Future<void> _save(WorkspacePreferences next) async {
    await store.write(next);
    preferences = next;
    _notify();
  }

  Future<void> addHost(String name, String address) async {
    final endpoint = WorkspaceEndpoint.parse(address);
    if (name.trim().isEmpty || name.length > 80) {
      throw const FormatException('Escribe un nombre de hasta 80 caracteres.');
    }
    if (preferences.hosts.any((h) => h.address == endpoint.address)) {
      throw const FormatException('Este ordenador ya está guardado.');
    }
    final id = List.generate(
      12,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _save(
      WorkspacePreferences(
        hosts: [
          ...preferences.hosts,
          WorkspaceHost(id: id, name: name.trim(), address: endpoint.address),
        ],
        customProfiles: preferences.customProfiles,
        selectedProfile: preferences.selectedProfile,
      ),
    );
  }

  Future<void> removeHost(String id) async {
    if (occupied) {
      throw StateError('Termina la sesión antes de eliminar el ordenador.');
    }
    await _save(
      WorkspacePreferences(
        hosts: preferences.hosts.where((h) => h.id != id).toList(),
        customProfiles: preferences.customProfiles,
        selectedProfile: preferences.selectedProfile,
      ),
    );
    observations.remove(id);
    probeErrors.remove(id);
    _notify();
  }

  Future<void> selectProfile(String id) async {
    if (occupied) {
      throw StateError('Termina la sesión antes de cambiar el perfil.');
    }
    if (![
      ...RemoteProfile.presets,
      ...preferences.customProfiles,
    ].any((p) => p.id == id)) {
      throw const FormatException('Perfil desconocido');
    }
    await _save(
      WorkspacePreferences(
        hosts: preferences.hosts,
        customProfiles: preferences.customProfiles,
        selectedProfile: id,
      ),
    );
  }

  Future<void> saveProfile(RemoteProfile value) async {
    if (occupied) {
      throw StateError('Termina la sesión antes de editar el perfil.');
    }
    value.validate();
    if (RemoteProfile.presets.any((p) => p.id == value.id)) {
      throw const FormatException(
        'Guarda un perfil personalizado con otro identificador.',
      );
    }
    await _save(
      WorkspacePreferences(
        hosts: preferences.hosts,
        customProfiles: [
          ...preferences.customProfiles.where((p) => p.id != value.id),
          value,
        ],
        selectedProfile: value.id,
      ),
    );
  }

  Future<void> inspect(WorkspaceHost host) async {
    if (!probing.add(host.id)) return;
    _notify();
    try {
      observations[host.id] = await probe.inspect(
        WorkspaceEndpoint.parse(host.address),
      );
      probeErrors.remove(host.id);
    } catch (error) {
      observations.remove(host.id);
      probeErrors[host.id] = 'No se pudo consultar Apollo. Comprueba dirección, red local/Tailscale, firewall y el puerto HTTP de Apollo.';
    } finally {
      probing.remove(host.id);
      _notify();
    }
  }

  Future<void> pairHost(WorkspaceHost host) async {
    if (occupied) return;
    if (capabilities?.integrated != true) {
      status = 'El motor nativo no está disponible en esta plataforma.';
      _notify();
      return;
    }
    activeHostId = host.id;
    pairingPin = null;
    state = WorkspaceState.pairing;
    status = 'Preparando emparejamiento con Apollo…';
    _notify();
    try {
      await engine.pair(host);
    } catch (error) {
      state = WorkspaceState.idle;
      status = 'No se pudo iniciar el emparejamiento: $error';
      _notify();
    }
  }

  Future<void> loadApps(WorkspaceHost host) async {
    if (occupied && !connected) return;
    try {
      final result = await engine.applications(host);
      applications = result.apps;
      permission = result.permission;
      virtualDisplayCapable = result.virtualDisplayCapable;
      virtualDisplayReady = result.virtualDisplayReady;
      activeHostId = host.id;
      status = applications.isEmpty
          ? 'Apollo no anunció aplicaciones para este cliente. Revisa su permiso de listar aplicaciones.'
          : 'Selecciona Escritorio o la aplicación que quieras abrir.';
    } catch (_) {
      applications = [];
      status = 'No se pudo consultar la lista autenticada. Empareja el PC y revisa sus permisos en Apollo.';
    }
    _notify();
  }

  Future<void> connect(
    WorkspaceHost host,
    String appId, {
    bool virtualDisplay = false,
  }) async {
    if (occupied) return;
    final block = captureBlock;
    if (block != null) {
      status = block;
      _notify();
      return;
    }
    if (capabilities?.integrated != true) {
      status = 'El motor nativo no está disponible en esta plataforma.';
      _notify();
      return;
    }
    final token = ++_generation;
    state = WorkspaceState.connecting;
    activeHostId = host.id;
    metrics = const RemoteMetrics();
    status = 'Conectando con el escritorio…';
    _notify();
    try {
      _restoreCamera =
          capture.status == CaptureStatus.live ||
          capture.status == CaptureStatus.opening;
      if (_restoreCamera) await capture.stop();
      if (token != _generation || _disposed) return;
      await engine.connect(
        host: host,
        appId: appId,
        profile: profile,
        virtualDisplay:
            virtualDisplay && virtualDisplayCapable && virtualDisplayReady,
      );
    } catch (_) {
      status = 'No se pudo iniciar la sesión. Comprueba emparejamiento, permisos y códec.';
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    if (state == WorkspaceState.disconnecting) return;
    _generation++;
    state = WorkspaceState.disconnecting;
    pairingPin = null;
    _notify();
    try {
      await engine.disconnect();
    } catch (_) {
      status = 'Se perdió la respuesta del motor. No se iniciará otra captura hasta cerrar el módulo.';
    } finally {
      state = WorkspaceState.idle;
      if (_restoreCamera && !_disposed) {
        _restoreCamera = false;
        await capture.start();
      }
      _notify();
    }
  }

  void _event(Map<String, dynamic> event) {
    if (_disposed) return;
    switch (event['type']) {
      case 'pairing':
        pairingPin = event['pin'] as String?;
        status = 'Introduce este PIN en la sección de emparejamiento de Apollo en Windows.';
      case 'paired':
        pairingPin = null;
        state = WorkspaceState.idle;
        status = 'Ordenador emparejado. Consulta sus aplicaciones.';
      case 'state':
        if (event['state'] == 'connected') {
          state = WorkspaceState.connected;
          status = 'Escritorio conectado';
        } else if (event['state'] == 'disconnected' &&
            state != WorkspaceState.disconnecting &&
            state != WorkspaceState.idle) {
          unawaited(disconnect());
        }
      case 'error':
        status = event['message'] as String? ?? 'Error de sesión';
        pairingPin = null;
        unawaited(disconnect());
      case 'stage':
        status = event['message'] as String? ?? status;
      case 'metrics':
        metrics = RemoteMetrics.fromNative(event);
      case 'quality':
        if (event['status'] != 0) status = 'La conexión informa pérdida o congestión. Prueba un perfil de menor bitrate.';
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_events?.cancel());
    unawaited(engine.disconnect());
    super.dispose();
  }
}
