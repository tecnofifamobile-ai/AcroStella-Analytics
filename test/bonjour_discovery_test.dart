import 'dart:async';

import 'package:acrostella_analytics/src/connection/peer_discovery.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.haberey/nsd');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Future<void> emit(String method, Map<dynamic, dynamic> arguments) {
    final done = Completer<void>();
    ServicesBinding.instance.channelBuffers.push(
      channel.name,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      (reply) {
        if (reply != null) codec.decodeEnvelope(reply);
        done.complete();
      },
    );
    return done.future;
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'Bonjour resolves protocol v3 peers and removes lost services',
    () async {
      final calls = <MethodCall>[];
      String? handle;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        final args = Map<dynamic, dynamic>.from(call.arguments as Map);
        switch (call.method) {
          case 'startDiscovery':
            handle = args['handle'] as String;
            expect(args['service.type'], '_acrostella._tcp');
            await emit('onDiscoveryStartSuccessful', args);
          case 'resolve':
            await emit('onResolveSuccessful', {
              ...args,
              'service.addresses': '192.168.43.1',
              'service.port': 45872,
              'service.txt': {
                'protocol': Uint8List.fromList([51]),
              },
            });
          case 'stopDiscovery':
            await emit('onDiscoveryStopSuccessful', args);
        }
        return null;
      });
      final discovery = BonjourPeerDiscovery();
      var peers = <CameraPeer>[];
      await discovery.browse((found) => peers = found);
      await emit('onServiceDiscovered', {
        'handle': handle,
        'service.name': 'Camera ABC',
        'service.type': '_acrostella._tcp',
      });
      // The plugin resolves service discovery asynchronously.
      for (var i = 0; i < 50 && peers.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(peers.single.endpoint, '192.168.43.1:45872');
      await emit('onServiceLost', {
        'handle': handle,
        'service.name': 'Camera ABC',
        'service.type': '_acrostella._tcp',
      });
      expect(peers, isEmpty);
      await discovery.stopBrowsing();
      expect(calls.last.method, 'stopDiscovery');
    },
  );

  test('a late Bonjour registration is withdrawn after cancellation; TXT contains no code', () async {
    Map<dynamic, dynamic>? pending;
    final withdrawn = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = Map<dynamic, dynamic>.from(call.arguments as Map);
      if (call.method == 'register') {
        pending = args;
        expect((args['service.txt'] as Map).keys, ['protocol']);
      } else if (call.method == 'unregister') {
        withdrawn.add(args['handle'] as String);
        await emit('onUnregistrationSuccessful', args);
      }
      return null;
    });
    final discovery = BonjourPeerDiscovery();
    final advertising = discovery.advertise('Camera ABC', 45872);
    for (var i = 0; i < 50 && pending == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await discovery.stopAdvertising();
    await emit('onRegistrationSuccessful', pending!);
    await advertising;
    expect(withdrawn, [pending!['handle']]);
  });
}
