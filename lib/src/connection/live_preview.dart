import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../capture/flutter_camera_device.dart';

/// LAN-only WebRTC. SDP/ICE travel over the already authenticated control
/// channel; no public STUN, TURN, signalling service or second camera owner.
class LivePreview extends ChangeNotifier {
  LivePreview(this.device);
  final FlutterCameraDevice device;
  RTCPeerConnection? _peer;
  RTCVideoRenderer? _renderer;
  final _candidates = <RTCIceCandidate>[];
  bool _remoteDescription = false, _disposed = false;
  int _generation = 0;
  String status = 'Vista remota sin conectar';
  bool get ready => _renderer?.renderVideo == true;
  Widget view() => _renderer == null
      ? const SizedBox.shrink()
      : RTCVideoView(
          _renderer!,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        );
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start({
    required bool camera,
    required Future<void> Function(Map<String, dynamic>) send,
  }) async {
    await stop();
    final generation = _generation;
    status = camera
        ? 'Enviando vista de la cámara…'
        : 'Conectando vídeo en directo…';
    _notify();
    final peer = await createPeerConnection({
      'iceServers': <dynamic>[],
      'sdpSemantics': 'unified-plan',
    });
    if (generation != _generation) {
      await peer.close();
      await peer.dispose();
      return;
    }
    _peer = peer;
    peer.onIceCandidate = (candidate) {
      if (_peer != peer || candidate.candidate == null) return;
      unawaited(
        send({'type': 'preview', 'kind': 'ice', 'candidate': candidate.toMap()})
            .catchError((Object _, StackTrace _) {}),
      );
    };
    peer.onConnectionState = (state) {
      if (_peer != peer) return;
      status = switch (state) {
        RTCPeerConnectionState.RTCPeerConnectionStateConnected =>
          'Directo · red local',
        RTCPeerConnectionState.RTCPeerConnectionStateFailed =>
          'Vista interrumpida · vuelve a conectar el vídeo',
        RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
          'Recuperando vídeo…',
        _ => 'Conectando vídeo en directo…',
      };
      _notify();
    };
    if (camera) {
      final stream = device.stream;
      if (stream == null) throw StateError('Camera not ready');
      final sender = await peer.addTrack(
        stream.getVideoTracks().single,
        stream,
      );
      final parameters = sender.parameters;
      parameters.encodings = [
        RTCRtpEncoding(
          maxBitrate: 2000000,
          maxFramerate: 30,
          scaleResolutionDownBy: 1.5,
        ),
      ];
      try {
        await sender.setParameters(parameters);
      } catch (_) {
        /* Device codec defaults remain usable. */
      }
      final offer = await peer.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });
      await peer.setLocalDescription(offer);
      await send({'type': 'preview', 'kind': 'offer', 'sdp': offer.toMap()});
    } else {
      final renderer = RTCVideoRenderer();
      _renderer = renderer;
      await renderer.initialize();
      if (_peer != peer) {
        await renderer.dispose();
        return;
      }
      renderer.onFirstFrameRendered = _notify;
      renderer.onResize = _notify;
      peer.onTrack = (event) {
        if (_peer != peer ||
            event.track.kind != 'video' ||
            event.streams.isEmpty) {
          return;
        }
        renderer.srcObject = event.streams.first;
        _notify();
      };
      await send({'type': 'preview', 'kind': 'ready'});
    }
  }

  Future<void> handle(
    Map<String, dynamic> message,
    Future<void> Function(Map<String, dynamic>) send,
  ) async {
    final peer = _peer;
    if (peer == null) return;
    switch (message['kind']) {
      case 'ice':
        final data = message['candidate'] as Map<String, dynamic>;
        final line = data['candidate'] as String?;
        if (line == null || line.length > 4096) {
          throw const FormatException('ICE size');
        }
        // No relays or external candidates are needed for the local-only mode.
        if (!line.contains(' typ host')) return;
        final candidate = RTCIceCandidate(
          line,
          data['sdpMid'] as String?,
          data['sdpMLineIndex'] as int?,
        );
        if (_remoteDescription) {
          await peer.addCandidate(candidate);
        } else if (_candidates.length < 64) {
          _candidates.add(candidate);
        }
      case 'offer':
      case 'answer':
        final data = message['sdp'] as Map<String, dynamic>;
        final sdp = data['sdp'] as String;
        if (sdp.length > 60000 ||
            data['type'] != message['kind'] ||
            RegExp(r'^m=audio [1-9]', multiLine: true).hasMatch(sdp)) {
          throw const FormatException('Invalid SDP');
        }
        await peer.setRemoteDescription(
          RTCSessionDescription(sdp, data['type'] as String),
        );
        _remoteDescription = true;
        for (final candidate in _candidates) {
          await peer.addCandidate(candidate);
        }
        _candidates.clear();
        if (message['kind'] == 'offer') {
          final answer = await peer.createAnswer();
          await peer.setLocalDescription(answer);
          await send({
            'type': 'preview',
            'kind': 'answer',
            'sdp': answer.toMap(),
          });
        }
    }
  }

  Future<void> stop() async {
    _generation++;
    final peer = _peer, renderer = _renderer;
    _peer = null;
    _renderer = null;
    _remoteDescription = false;
    _candidates.clear();
    await peer?.close();
    await peer?.dispose();
    if (renderer != null) {
      renderer.srcObject = null;
      await renderer.dispose();
    }
    status = 'Vista remota sin conectar';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
