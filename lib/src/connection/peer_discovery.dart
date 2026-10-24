import 'dart:convert';

import 'package:nsd/nsd.dart' as nsd;

class CameraPeer {
  const CameraPeer(this.name, this.address, this.port, {this.id});
  final String name, address;
  final int port;
  final String? id;
  String get endpoint => '$address:$port';
}

/// App-owned DNS-SD resources. No discovery starts until the user asks.
/// The service publishes only its endpoint and protocol, never the code.
abstract interface class PeerDiscovery {
  Future<void> advertise(String name, int port);
  Future<void> browse(void Function(List<CameraPeer>) changed);
  Future<void> stopBrowsing();
  Future<void> stopAdvertising();
}

class BonjourPeerDiscovery implements PeerDiscovery {
  static const serviceType = '_acrostella._tcp';
  nsd.Discovery? _discovery;
  nsd.Registration? _registration;
  void Function()? _discoveryListener;
  int _browseGeneration = 0, _advertiseGeneration = 0;

  @override
  Future<void> advertise(String name, int port) async {
    final generation = ++_advertiseGeneration;
    final previous = _registration;
    _registration = null;
    if (previous != null) await nsd.unregister(previous);
    if (generation != _advertiseGeneration) return;
    final registration = await nsd.register(
      nsd.Service(
        name: name,
        type: serviceType,
        port: port,
        txt: {
          'protocol': utf8.encode('3'),
          if (RegExp(r'[a-f0-9]{32}$').hasMatch(name))
            'id': utf8.encode(name.substring(name.length - 32)),
        },
      ),
    );
    if (generation != _advertiseGeneration) {
      await nsd.unregister(registration);
      return;
    }
    _registration = registration;
  }

  @override
  Future<void> browse(void Function(List<CameraPeer>) changed) async {
    final generation = ++_browseGeneration;
    final previous = _discovery;
    _discovery = null;
    if (previous != null) {
      if (_discoveryListener != null) {
        previous.removeListener(_discoveryListener!);
      }
      _discoveryListener = null;
      await nsd.stopDiscovery(previous);
    }
    if (generation != _browseGeneration) return;
    final discovery = await nsd.startDiscovery(
      serviceType,
      ipLookupType: nsd.IpLookupType.v4,
    );
    if (generation != _browseGeneration) {
      await nsd.stopDiscovery(discovery);
      return;
    }
    _discovery = discovery;
    void update() {
      if (generation != _browseGeneration) return;
      changed([
        for (final service in discovery.services)
          if (service.port != null &&
              service.port! > 0 &&
              service.port! <= 65535 &&
              service.txt?['protocol'] != null &&
              utf8.decode(service.txt!['protocol']!, allowMalformed: true) ==
                  '3')
            for (final ip in service.addresses ?? [])
              CameraPeer(
                service.name ?? 'Cámara AcroStella',
                ip.address,
                service.port!,
                id: service.txt?['id'] == null
                    ? null
                    : utf8.decode(service.txt!['id']!, allowMalformed: true),
              ),
      ]);
    }

    _discoveryListener = update;
    discovery.addListener(update);
    update();
  }

  @override
  Future<void> stopBrowsing() async {
    _browseGeneration++;
    final discovery = _discovery;
    _discovery = null;
    if (discovery != null) {
      if (_discoveryListener != null) {
        discovery.removeListener(_discoveryListener!);
      }
      _discoveryListener = null;
      await nsd.stopDiscovery(discovery);
    }
  }

  @override
  Future<void> stopAdvertising() async {
    _advertiseGeneration++;
    final registration = _registration;
    _registration = null;
    if (registration != null) await nsd.unregister(registration);
  }
}
