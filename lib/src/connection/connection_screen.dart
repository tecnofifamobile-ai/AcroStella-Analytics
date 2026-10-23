import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pair_controller.dart';
import 'peer_discovery.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({
    required this.pair,
    this.installedVersion,
    super.key,
  });
  final PairController pair;
  final String? installedVersion;
  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _code = TextEditingController(), _ip = TextEditingController();
  String? _selected;
  bool _manual = false;

  @override
  void dispose() {
    widget.pair.stopSearch();
    _code.dispose();
    _ip.dispose();
    super.dispose();
  }

  Future<void> _connectPeer(CameraPeer peer) async {
    setState(() {
      _selected = peer.endpoint;
      _manual = false;
    });
    for (final remembered in widget.pair.trusted) {
      if (remembered.id == peer.id) {
        await widget.pair.reconnect(remembered, endpoint: peer.endpoint);
        return;
      }
    }
    var digits = '';
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Conectar esta cámara',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Escribe las seis cifras que muestra el otro dispositivo. La próxima vez lo recordaremos.',
            ),
            const SizedBox(height: 20),
            TextField(
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: const TextStyle(fontSize: 32, letterSpacing: 8),
              decoration: const InputDecoration(
                labelText: 'Código de seis cifras',
                hintText: '000000',
              ),
              onChanged: (value) => digits = value,
              onSubmitted: (value) => Navigator.pop(sheetContext, value),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(sheetContext, digits),
              icon: const Icon(Icons.link),
              label: const Text('Conectar y recordar'),
            ),
          ],
        ),
      ),
    );
    if (code != null && mounted) await widget.pair.join(peer.endpoint, code);
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dispositivos')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.pair,
        builder: (context, _) {
          final pair = widget.pair;
          final endpoints = pair.peers.map((p) => p.endpoint).toSet();
          final selected = endpoints.contains(_selected)
              ? _selected
              : endpoints.length == 1
              ? endpoints.single
              : null;
          final code = pair.pairingCode;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Icon(
                    pair.connected ? Icons.link : Icons.devices,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    pair.connected
                        ? 'Dos perspectivas. Un ejercicio.'
                        : 'Conecta con seis cifras.',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(pair.status, textAlign: TextAlign.center),
                  if (widget.installedVersion != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Instalada: ${widget.installedVersion}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (pair.busy)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: LinearProgressIndicator(
                        value: pair.progress > 0 ? pair.progress : null,
                      ),
                    ),
                  if (pair.trusted.isNotEmpty) ...[
                    _heading('Tus dispositivos'),
                    for (final device in pair.trusted)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            pair.connected
                                ? Icons.verified_user_outlined
                                : Icons.devices,
                          ),
                          title: Text(device.name),
                          subtitle: const Text(
                            'Recordado · sin volver a escribir el código',
                          ),
                          onTap:
                              pair.busy ||
                                  pair.connected ||
                                  pair.hosting ||
                                  device.endpoint.isEmpty
                              ? null
                              : () => pair.reconnect(device),
                          trailing: IconButton(
                            tooltip: 'Olvidar dispositivo',
                            onPressed: pair.busy || pair.recording
                                ? null
                                : () => pair.forget(device.id),
                            icon: const Icon(Icons.link_off),
                          ),
                        ),
                      ),
                  ],
                  if (!pair.connected && !pair.hosting) ...[
                    if (defaultTargetPlatform != TargetPlatform.iOS)
                      _heading('Convertir este dispositivo en cámara'),
                    if (defaultTargetPlatform != TargetPlatform.iOS)
                      FilledButton.icon(
                        onPressed: pair.busy ? null : pair.host,
                        icon: const Icon(Icons.videocam_outlined),
                        label: const Text('Usar como segunda cámara'),
                      ),
                    _heading('Añadir otra cámara a este estudio'),
                    const Text(
                      'Ambos dispositivos en la misma Wi-Fi o en el hotspot del Android. Usa 0.6.0 o posterior en los dos. El código solo es necesario la primera vez.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: pair.busy
                          ? null
                          : pair.searching
                          ? pair.stopSearch
                          : pair.search,
                      icon: Icon(pair.searching ? Icons.stop : Icons.radar),
                      label: Text(
                        pair.searching ? 'Detener búsqueda' : 'Buscar cámaras',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(pair.discoveryStatus),
                    if (pair.searching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                    for (final peer in pair.peers)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          selected == peer.endpoint
                              ? Icons.check_circle
                              : Icons.videocam_outlined,
                        ),
                        title: Text(
                          peer.name.startsWith('AcroStella Camera ')
                              ? 'Cámara ${peer.name.substring(peer.name.length - 4).toUpperCase()}'
                              : peer.name,
                        ),
                        subtitle: Text(
                          pair.trusted.any((d) => d.id == peer.id)
                              ? 'Recordada · toca para reconectar'
                              : 'Toca para conectar con seis cifras',
                        ),
                        selected: selected == peer.endpoint,
                        onTap: pair.busy ? null : () => _connectPeer(peer),
                      ),
                    ExpansionTile(
                      key: ValueKey(_manual),
                      initiallyExpanded: _manual,
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Conexión manual por IP'),
                      subtitle: const Text(
                        'Si tu cámara no aparece en la búsqueda',
                      ),
                      onExpansionChanged: (open) =>
                          setState(() => _manual = open),
                      children: [
                        TextField(
                          controller: _ip,
                          enabled: !pair.busy,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'IP del Android',
                            hintText: '192.168.43.1',
                            helperText:
                                'Aparece en «Conexión manual» del Android.',
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _code,
                      enabled: !pair.busy,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: const TextStyle(fontSize: 28, letterSpacing: 8),
                      decoration: const InputDecoration(
                        labelText: 'Código de seis cifras',
                        hintText: '000000',
                        helperText:
                            'El código que muestra la pantalla del Android.',
                      ),
                      onSubmitted: (_) => pair.join(
                        _manual ? _ip.text : selected ?? '',
                        _code.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: pair.busy
                          ? null
                          : () => pair.join(
                              _manual ? _ip.text : selected ?? '',
                              _code.text,
                            ),
                      icon: const Icon(Icons.link),
                      label: const Text('Conectar cámara'),
                    ),
                  ],
                  if (!pair.connected &&
                      !pair.hosting &&
                      defaultTargetPlatform == TargetPlatform.iOS)
                    ExpansionTile(
                      title: const Text('Usar este iPad como segunda cámara'),
                      subtitle: const Text(
                        'Solo si la revisión se controla desde otro dispositivo',
                      ),
                      children: [
                        FilledButton.icon(
                          onPressed: pair.busy ? null : pair.host,
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('Preparar cámara en este iPad'),
                        ),
                      ],
                    ),
                  if (pair.hosting && !pair.connected) ...[
                    _heading('Introduce este código en el iPad'),
                    if (pair.cameraName != null)
                      Text(
                        'Cámara ${pair.cameraName!.substring(pair.cameraName!.length - 4).toUpperCase()}',
                        textAlign: TextAlign.center,
                      ),
                    if (code != null) ...[
                      Semantics(
                        label: 'Código ${code.split('').join(' ')}',
                        child: SelectableText(
                          '${code.substring(0, 3)} ${code.substring(3)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 48,
                            letterSpacing: 6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Caduca en cinco minutos. Después de conectar recordaremos el iPad; al volver a la app se recuperará la conexión.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: code)),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar seis cifras'),
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: pair.busy ? null : pair.host,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Generar otro código'),
                    ),
                    ExpansionTile(
                      title: const Text('Conexión manual'),
                      subtitle: const Text(
                        'Usa una de estas IP si la búsqueda no encuentra la cámara',
                      ),
                      children: [
                        for (final address in pair.addresses)
                          ListTile(
                            title: SelectableText(address),
                            trailing: IconButton(
                              tooltip: 'Copiar IP',
                              icon: const Icon(Icons.copy),
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: address),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (pair.connected && !pair.hosting) ...[
                    _heading('Listo para entrenar'),
                    const Text(
                      'Vuelve al estudio para ver ambas cámaras. Controla la ejecución desde aquí; al terminar reuniremos los vídeos para revisarlos con un único cursor.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.video_camera_back_outlined),
                      label: const Text('Volver al estudio'),
                    ),
                  ],
                  if (pair.transferPending) ...[
                    OutlinedButton(
                      onPressed: pair.busy || pair.recording
                          ? null
                          : pair.finishExercise,
                      child: const Text('Reintentar transferencia pendiente'),
                    ),
                    TextButton(
                      onPressed: pair.busy ? null : pair.keepLocal,
                      child: const Text('Continuar con el vídeo local'),
                    ),
                  ],
                  if (pair.connected || pair.hosting)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: TextButton(
                        onPressed: pair.busy || pair.recording
                            ? null
                            : pair.disconnect,
                        child: const Text('Desconectar'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Vídeos cifrados por tu red local, sin cuenta ni nube. Mantén ambas pantallas desbloqueadas. En el estudio puedes ver los dos ángulos en directo. Para revisar se transfiere el archivo original, sin usar la latencia del directo para sincronizarlo.',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
