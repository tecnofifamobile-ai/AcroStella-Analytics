import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

class WorkspaceEndpoint {
  const WorkspaceEndpoint(this.host, this.port);
  final String host;
  final int port;
  Uri get uri =>
      Uri(scheme: 'http', host: host, port: port, path: '/serverinfo');
  String get address => host.contains(':') ? '[$host]:$port' : '$host:$port';
  bool get tailnet {
    final ip = InternetAddress.tryParse(host);
    return host.endsWith('.ts.net') ||
        (ip?.type == InternetAddressType.IPv4 &&
            ip!.rawAddress[0] == 100 &&
            ip.rawAddress[1] >= 64 &&
            ip.rawAddress[1] <= 127);
  }

  static bool privateAddress(InternetAddress ip) {
    final b = ip.rawAddress;
    if (ip.isLoopback) return true;
    if (ip.type == InternetAddressType.IPv4) {
      return b[0] == 10 ||
          (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
          (b[0] == 192 && b[1] == 168) ||
          (b[0] == 169 && b[1] == 254) ||
          (b[0] == 100 && b[1] >= 64 && b[1] <= 127);
    }
    return b[0] == 0xfd || (b[0] == 0xfe && (b[1] & 0xc0) == 0x80);
  }

  factory WorkspaceEndpoint.parse(String value) {
    final input = value.trim().toLowerCase();
    final uri = Uri.tryParse(input.contains('://') ? input : 'http://$input');
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'Usa una IP privada o un nombre .local / .ts.net, sin rutas ni contraseñas.',
      );
    }
    final host = uri.host;
    final ip = InternetAddress.tryParse(host);
    if (ip != null
        ? !privateAddress(ip)
        : (!RegExp(r'^[a-z0-9](?:[a-z0-9.-]{0,250})\.(?:local|ts\.net)$')
              .hasMatch(host))) {
      throw const FormatException(
        'Solo se permiten direcciones de red local o Tailscale; no abras puertos públicos.',
      );
    }
    final port = uri.hasPort ? uri.port : 47989;
    if (port < 1 || port > 65535) {
      throw const FormatException('Puerto inválido.');
    }
    return WorkspaceEndpoint(host, port);
  }
}

class ApolloObservation {
  const ApolloObservation({
    required this.name,
    required this.serverId,
    required this.version,
    required this.checkedAt,
    required this.queryMilliseconds,
    this.codecModes,
  });
  final String name, serverId, version;
  final DateTime checkedAt;

  /// HTTP query time includes server processing and may include DNS/TCP.
  /// It is neither streaming RTT nor end-to-end interaction latency.
  final int queryMilliseconds;
  final int? codecModes;
  factory ApolloObservation.parse(String xml, Duration queryTime) {
    if (xml.length > 64 * 1024 ||
        RegExp(r'<!\s*(DOCTYPE|ENTITY)', caseSensitive: false).hasMatch(xml)) {
      throw const FormatException('Respuesta XML no admitida.');
    }
    final doc = XmlDocument.parse(xml);
    final root = doc.rootElement;
    if (root.name.local != 'root' ||
        root.getAttribute('status_code') != '200') {
      throw const FormatException('El servidor no confirmó GameStream.');
    }
    String field(String name) => root.getElement(name)?.innerText.trim() ?? '';
    final name = field('hostname'),
        id = field('uniqueid'),
        version = field('appversion');
    if (name.isEmpty ||
        name.length > 256 ||
        id.isEmpty ||
        id.length > 128 ||
        version.isEmpty ||
        version.length > 80) {
      throw const FormatException('Información del servidor incompleta.');
    }
    return ApolloObservation(
      name: name,
      serverId: id,
      version: version,
      checkedAt: DateTime.now(),
      queryMilliseconds: queryTime.inMilliseconds,
      codecModes: int.tryParse(field('ServerCodecModeSupport')),
    );
  }
}

class ApolloProbe {
  Future<ApolloObservation> inspect(WorkspaceEndpoint endpoint) async {
    final addresses = await InternetAddress.lookup(endpoint.host)
        .timeout(const Duration(seconds: 4));
    if (addresses.isEmpty ||
        addresses.any((ip) => !WorkspaceEndpoint.privateAddress(ip))) {
      throw const FormatException(
        'El nombre no resuelve exclusivamente a una red local o Tailscale.',
      );
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..findProxy = ((_) => 'DIRECT');
    final clock = Stopwatch()..start();
    try {
      final request = await client
          .getUrl(endpoint.uri)
          .timeout(const Duration(seconds: 5));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) {
        throw const HttpException('El servidor no respondió con HTTP 200.');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 5))) {
        if (bytes.length + chunk.length > 64 * 1024) {
          throw const FormatException('Respuesta demasiado grande.');
        }
        bytes.addAll(chunk);
      }
      return ApolloObservation.parse(utf8.decode(bytes), clock.elapsed);
    } finally {
      client.close(force: true);
    }
  }
}
