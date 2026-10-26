import 'package:flutter/services.dart';

import 'remote_models.dart';

/// UI and configuration are shared. A real engine owns native transport,
/// hardware decoder, rendering and input. Video frames never cross this API.
abstract interface class WorkspaceEngine {
  Future<WorkspaceCapabilities> capabilities();
  Stream<RemoteMetrics> get metrics;
  Future<void> connect({
    required String hostId,
    required RemoteProfile profile,
  });
  Future<void> disconnect();
}

class NativeWorkspaceEngine implements WorkspaceEngine {
  static const channel = MethodChannel('acrostella/workspace');
  @override
  Stream<RemoteMetrics> get metrics => const Stream.empty();
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
        reason: 'El motor de escritorio remoto todavía no está integrado en esta compilación.',
      );
    }
  }

  @override
  Future<void> connect({
    required String hostId,
    required RemoteProfile profile,
  }) async {
    final support = await capabilities();
    if (!support.integrated) {
      throw StateError(support.reason ?? 'Motor no disponible');
    }
    profile.validate();
    await channel.invokeMethod<void>('connect', {
      'hostId': hostId,
      'profile': profile.toJson(),
    });
  }

  @override
  Future<void> disconnect() async {
    final support = await capabilities();
    if (support.integrated) await channel.invokeMethod<void>('disconnect');
  }
}
