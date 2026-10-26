enum RemoteCodec { h264, hevc, av1 }

enum PresentationPolicy { lowLatency, paced }

enum PointerMode { direct, trackpad }

class RemoteProfile {
  const RemoteProfile({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.bitrateMbps,
    this.fps = 60,
    this.codec = RemoteCodec.hevc,
    this.presentation = PresentationPolicy.lowLatency,
    this.pointer = PointerMode.trackpad,
  });
  final String id, name;
  final int width, height, fps, bitrateMbps;
  final RemoteCodec codec;
  final PresentationPolicy presentation;
  final PointerMode pointer;
  static const presets = [
    RemoteProfile(
      id: 'balanced',
      name: 'Equilibrado',
      width: 2732,
      height: 2048,
      bitrateMbps: 10,
    ),
    RemoteProfile(
      id: 'quality',
      name: 'Calidad máxima',
      width: 2732,
      height: 2048,
      bitrateMbps: 12,
      presentation: PresentationPolicy.paced,
    ),
    RemoteProfile(
      id: 'latency',
      name: 'Latencia mínima',
      width: 2048,
      height: 1536,
      bitrateMbps: 8,
    ),
  ];
  void validate() {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id) ||
        name.trim().isEmpty ||
        name.length > 80 ||
        width < 320 ||
        width > 7680 ||
        height < 240 ||
        height > 4320 ||
        width.isOdd ||
        height.isOdd ||
        ![24, 30, 60].contains(fps) ||
        bitrateMbps < 1 ||
        bitrateMbps > 150) {
      throw const FormatException(
        'Perfil inválido: usa resolución par, 24/30/60 FPS y 1–150 Mbps.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'width': width,
    'height': height,
    'fps': fps,
    'bitrateMbps': bitrateMbps,
    'codec': codec.name,
    'presentation': presentation.name,
    'pointer': pointer.name,
  };
  factory RemoteProfile.fromJson(Map<String, dynamic> data) {
    final profile = RemoteProfile(
      id: data['id'] as String,
      name: data['name'] as String,
      width: data['width'] as int,
      height: data['height'] as int,
      bitrateMbps: data['bitrateMbps'] as int,
      fps: data['fps'] as int,
      codec: RemoteCodec.values.byName(data['codec'] as String),
      presentation: PresentationPolicy.values.byName(
        data['presentation'] as String,
      ),
      pointer: PointerMode.values.byName(data['pointer'] as String),
    );
    profile.validate();
    return profile;
  }
}

/// Null means unavailable, never zero. Transport RTT is not input-to-display
/// latency; application probes and Tailscale routing are separate observations.
class RemoteMetrics {
  const RemoteMetrics({
    this.receivedFps,
    this.presentedFps,
    this.networkRttMs,
    this.jitterMs,
    this.droppedFrames,
    this.encodeMs,
    this.decodeMs,
    this.presentationMs,
    this.actualMbps,
    this.codec,
    this.width,
    this.height,
    this.hostProcessingMs,
    this.rttVarianceMs,
  });
  final double? receivedFps,
      presentedFps,
      networkRttMs,
      jitterMs,
      encodeMs,
      decodeMs,
      presentationMs,
      actualMbps,
      hostProcessingMs,
      rttVarianceMs;
  final int? droppedFrames, width, height;
  final String? codec;
  factory RemoteMetrics.fromNative(Map<String, dynamic> data) {
    double? number(String key) {
      final value = data[key];
      return value is num && value.isFinite && value >= 0
          ? value.toDouble()
          : null;
    }

    return RemoteMetrics(
      receivedFps: number('receivedFps'),
      presentedFps: number('presentedFps'),
      networkRttMs: number('networkRttMs'),
      jitterMs: number('jitterMs'),
      encodeMs: number('encodeMs'),
      decodeMs: number('decodeMs'),
      presentationMs: number('presentationMs'),
      actualMbps: number('actualMbps'),
      droppedFrames: (data['droppedFrames'] as num?)?.toInt(),
      codec: data['codec'] as String?,
      width: (data['width'] as num?)?.toInt(),
      height: (data['height'] as num?)?.toInt(),
      hostProcessingMs: number('hostProcessingMs'),
      rttVarianceMs: number('rttVarianceMs'),
    );
  }
}

class WorkspaceCapabilities {
  const WorkspaceCapabilities({
    required this.platform,
    required this.integrated,
    this.h264Hardware,
    this.hevcHardware,
    this.av1Hardware,
    this.reason,
  });
  final String platform;
  final bool integrated;
  final bool? h264Hardware, hevcHardware, av1Hardware;
  final String? reason;
}
