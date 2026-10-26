import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;

import 'apollo_probe.dart';

class DiscoveredWorkspaceHost {
  const DiscoveredWorkspaceHost(this.name, this.endpoint);
  final String name;
  final WorkspaceEndpoint endpoint;
}

/// Discovery is a hint, never trust. Pairing still authenticates the server.
class WorkspaceDiscovery extends ChangeNotifier {
  nsd.Discovery? _discovery;
  VoidCallback? _listener;
  Timer? _timer;
  int _generation = 0;
  bool searching = false, _disposed = false;
  List<DiscoveredWorkspaceHost> hosts = [];
  String status =
      'La búsqueda encuentra ordenadores en la red local; Tailscale se añade por dirección.';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> search() async {
    if (searching) return;
    final token = ++_generation;
    searching = true;
    hosts = [];
    status = 'Buscando Apollo / GameStream en la red local…';
    _notify();
    try {
      final discovery = await nsd
          .startDiscovery('_nvstream._tcp', ipLookupType: nsd.IpLookupType.v4)
          .timeout(const Duration(seconds: 8));
      if (token != _generation) {
        await nsd.stopDiscovery(discovery);
        return;
      }
      _discovery = discovery;
      void update() {
        if (token != _generation) return;
        final found = <String, DiscoveredWorkspaceHost>{};
        for (final service in discovery.services) {
          final port = service.port;
          if (port == null || port < 1 || port > 65535) continue;
          for (final ip in service.addresses ?? []) {
            if (!WorkspaceEndpoint.privateAddress(ip)) continue;
            final endpoint = WorkspaceEndpoint(ip.address, port);
            found[endpoint.address] = DiscoveredWorkspaceHost(
              service.name ?? 'Ordenador GameStream',
              endpoint,
            );
          }
        }
        hosts = found.values.toList();
        status = hosts.isEmpty
            ? 'Buscando… Comprueba que Apollo anuncia el equipo y permite la red local.'
            : 'Selecciona el ordenador que quieras guardar.';
        _notify();
      }

      _listener = update;
      discovery.addListener(update);
      update();
      _timer = Timer(const Duration(seconds: 30), () => unawaited(stop()));
    } catch (_) {
      searching = false;
      status = 'No se pudo buscar. Puedes añadir la IP o el nombre Tailscale manualmente.';
      _notify();
    }
  }

  Future<void> stop() async {
    _generation++;
    _timer?.cancel();
    _timer = null;
    final discovery = _discovery;
    _discovery = null;
    if (discovery != null) {
      if (_listener != null) discovery.removeListener(_listener!);
      try {
        await nsd.stopDiscovery(discovery);
      } catch (_) {}
    }
    _listener = null;
    searching = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
