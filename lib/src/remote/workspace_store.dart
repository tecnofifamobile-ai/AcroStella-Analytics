import 'dart:convert';
import 'dart:io';

import 'remote_models.dart';

class WorkspaceHost {
  const WorkspaceHost({
    required this.id,
    required this.name,
    required this.address,
  });
  final String id, name, address;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'address': address};
  factory WorkspaceHost.fromJson(Map<String, dynamic> data) {
    final host = WorkspaceHost(
      id: data['id'] as String,
      name: data['name'] as String,
      address: data['address'] as String,
    );
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(host.id) ||
        host.name.trim().isEmpty ||
        host.name.length > 80 ||
        host.address.length > 256) {
      throw const FormatException('Ordenador inválido');
    }
    return host;
  }
}

class WorkspacePreferences {
  const WorkspacePreferences({
    this.hosts = const [],
    this.customProfiles = const [],
    this.selectedProfile = 'balanced',
  });
  final List<WorkspaceHost> hosts;
  final List<RemoteProfile> customProfiles;
  final String selectedProfile;
}

/// This file contains addresses/profiles only. Pairing identities and private
/// keys belong in native secure storage, never in this preferences document.
class WorkspaceStore {
  WorkspaceStore(this.directory);
  final Future<Directory> Function() directory;
  Future<void> _pending = Future.value();
  Future<WorkspacePreferences> read() async {
    final file = File('${(await directory()).path}/workspace-v1.json');
    if (!await file.exists()) return const WorkspacePreferences();
    if (await file.length() > 64 * 1024) {
      throw const FormatException('Configuración demasiado grande');
    }
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (data['schema'] != 1) {
      throw const FormatException('Configuración incompatible');
    }
    final hosts = (data['hosts'] as List)
        .map((v) => WorkspaceHost.fromJson(v as Map<String, dynamic>))
        .toList();
    final profiles = (data['profiles'] as List)
        .map((v) => RemoteProfile.fromJson(v as Map<String, dynamic>))
        .toList();
    if (hosts.length > 16 ||
        profiles.length > 24 ||
        hosts.map((v) => v.id).toSet().length != hosts.length ||
        profiles.map((v) => v.id).toSet().length != profiles.length) {
      throw const FormatException('Configuración inválida');
    }
    final selected = data['selected'] as String;
    if (![...RemoteProfile.presets, ...profiles].any((v) => v.id == selected)) {
      throw const FormatException('Perfil desconocido');
    }
    return WorkspacePreferences(
      hosts: hosts,
      customProfiles: profiles,
      selectedProfile: selected,
    );
  }

  Future<void> write(WorkspacePreferences value) {
    final next = _pending.then((_) async {
      if (value.hosts.length > 16 || value.customProfiles.length > 24) {
        throw const FormatException('Demasiados perfiles o dispositivos');
      }
      for (final p in value.customProfiles) {
        p.validate();
      }
      for (final h in value.hosts) {
        WorkspaceHost.fromJson(h.toJson());
      }
      final profiles = [...RemoteProfile.presets, ...value.customProfiles];
      if (value.hosts.map((h) => h.id).toSet().length != value.hosts.length ||
          profiles.map((p) => p.id).toSet().length != profiles.length ||
          !profiles.any((p) => p.id == value.selectedProfile)) {
        throw const FormatException('Configuración inválida');
      }
      final dir = await directory();
      await dir.create(recursive: true);
      final file = File('${dir.path}/workspace-v1.json');
      final temp = File('${file.path}.part');
      await temp.writeAsString(
        jsonEncode({
          'schema': 1,
          'hosts': value.hosts.map((h) => h.toJson()).toList(),
          'profiles': value.customProfiles.map((p) => p.toJson()).toList(),
          'selected': value.selectedProfile,
        }),
        flush: true,
      );
      await temp.rename(file.path);
    });
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
