import 'package:flutter/services.dart';

import 'remote_models.dart';
import 'workspace_store.dart';

class WorkspaceApplications {
  const WorkspaceApplications({
    required this.apps,
    this.permission,
    this.virtualDisplayCapable = false,
    this.virtualDisplayReady = false,
  });
  final List<Map<String, String>> apps;
  final int? permission;
  final bool virtualDisplayCapable, virtualDisplayReady;
}

/// UI/configuration are shared. Native code owns transport, hardware decoding,
/// rendering and input; raw video frames never cross a platform channel.
abstract interface class WorkspaceEngine {
  Future<WorkspaceCapabilities> capabilities();
  Stream<Map<String, dynamic>> get events;
  Future<void> pair(WorkspaceHost host);
  Future<WorkspaceApplications> applications(WorkspaceHost host);
  Future<void> connect({
    required WorkspaceHost host,
    required String appId,
    required RemoteProfile profile,
    bool virtualDisplay = false,
  });
  Future<void> disconnect();
  Future<void> input(Map<String, dynamic> event);
  Future<void> keyboard(bool visible);
}

class NativeWorkspaceEngine implements WorkspaceEngine {
  static const channel = MethodChannel('acrostella/workspace');
  static const eventChannel = EventChannel('acrostella/workspace/events');
  @override
  Stream<Map<String, dynamic>> get events => eventChannel
      .receiveBroadcastStream()
      .map((v) => Map<String, dynamic>.from(v as Map));
  @override
  Future<WorkspaceCapabilities> capabilities() async {
    try {
      final data = await channel.invokeMapMethod<String, dynamic>(
        'capabilities',
      );
      return WorkspaceCapabilities(
        platform: data?['platform'] as String? ?? 'desconocida',
        integrated: data?['integrated'] == true,
        h264Hardware: data?['h264Hardware'] as bool?,
        hevcHardware: data?['hevcHardware'] as bool?,
        av1Hardware: data?['av1Hardware'] as bool?,
        reason: data?['reason'] as String?,
      );
    } on MissingPluginException {
      return const WorkspaceCapabilities(
        platform: 'sin adaptador',
        integrated: false,
        reason: 'El motor nativo de escritorio remoto no está disponible en esta plataforma.',
      );
    }
  }

  @override
  Future<void> pair(WorkspaceHost host) => channel.invokeMethod<void>('pair', {
    'hostId': host.id,
    'address': host.address,
  });
  @override
  Future<WorkspaceApplications> applications(WorkspaceHost host) async {
    final data = await channel.invokeMapMethod<String, dynamic>('apps', {
      'hostId': host.id,
      'address': host.address,
    });
    return WorkspaceApplications(
      apps: [
        for (final v in data?['apps'] as List? ?? [])
          Map<String, String>.from(v as Map),
      ],
      permission: data?['permission'] as int?,
      virtualDisplayCapable: data?['virtualDisplayCapable'] == true,
      virtualDisplayReady: data?['virtualDisplayReady'] == true,
    );
  }

  @override
  Future<void> connect({
    required WorkspaceHost host,
    required String appId,
    required RemoteProfile profile,
    bool virtualDisplay = false,
  }) async {
    final support = await capabilities();
    if (!support.integrated) {
      throw StateError(support.reason ?? 'Motor no disponible');
    }
    profile.validate();
    await channel.invokeMethod<void>('connect', {
      'hostId': host.id,
      'address': host.address,
      'appId': appId,
      'profile': profile.toJson(),
      'virtualDisplay': virtualDisplay,
    });
  }

  @override
  Future<void> disconnect() => channel.invokeMethod<void>('disconnect');
  @override
  Future<void> input(Map<String, dynamic> event) =>
      channel.invokeMethod<void>('input', event);
  @override
  Future<void> keyboard(bool visible) =>
      channel.invokeMethod<void>('keyboard', {'visible': visible});
}
