import 'package:flutter/material.dart';

import '../capture/capture_session.dart';
import 'update_controller.dart';
import 'update_source.dart';

class UpdateScreen extends StatelessWidget {
  const UpdateScreen({required this.updates, required this.capture, super.key});
  final UpdateController updates;
  final CaptureSession capture;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Actualizaciones')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([updates, capture]),
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          final release = updates.release;
          final ios = updates.app?.platform == UpdatePlatform.ios;
          final downloading = updates.phase == UpdatePhase.downloading;
          final ready = updates.phase == UpdatePhase.ready;
          final hasUpdate =
              updates.hasUpdate && updates.phase != UpdatePhase.incompatible;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      colors.primaryContainer,
                      colors.surfaceContainerHigh,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, size: 36, color: colors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'AcroStella Analytics',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      updates.app == null
                          ? 'Preparando actualizador…'
                          : 'Versión instalada · ${updates.app!.versionName}',
                    ),
                    const SizedBox(height: 8),
                    const Text('Nuevas herramientas, directamente en tu app.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (updates.phase == UpdatePhase.checking)
                const LinearProgressIndicator(),
              if (hasUpdate && release != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nueva versión ${release.versionName}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(release.bytes / (1024 * 1024)).toStringAsFixed(1)} MB · ${ios ? 'iOS / iPadOS' : 'Android'}',
                        ),
                        const SizedBox(height: 16),
                        Text(release.notes),
                        if (downloading) ...[
                          const SizedBox(height: 20),
                          LinearProgressIndicator(
                            value: (updates.received / release.bytes).clamp(
                              0,
                              1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Descargando · ${(100 * updates.received / release.bytes).clamp(0, 100).toStringAsFixed(0)} %',
                          ),
                          TextButton(
                            onPressed: updates.cancelDownload,
                            child: const Text('Cancelar descarga'),
                          ),
                        ],
                        if (!updates.busy && !ready) ...[
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: updates.download,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Descargar actualización'),
                          ),
                        ],
                        if (ready) ...[
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Icon(Icons.verified_outlined),
                              SizedBox(width: 8),
                              Text('Descarga verificada'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: capture.clipBusy
                                ? null
                                : updates.install,
                            icon: const Icon(Icons.system_update_alt),
                            label: Text(
                              ios
                                  ? 'Enviar IPA al firmador'
                                  : updates.app?.canInstall == false
                                  ? 'Permitir instalación'
                                  : 'Instalar actualización',
                            ),
                          ),
                          if (capture.clipBusy)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Finaliza el clip antes de instalar.',
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (updates.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    updates.message!,
                    key: const Key('update-message'),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: updates.busy ? null : updates.check,
                icon: const Icon(Icons.refresh),
                label: const Text('Buscar actualizaciones'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Avisarme de nuevas versiones'),
                subtitle: const Text(
                  'Consulta GitHub al abrir la app, como máximo una vez al día. No envía vídeos ni entrenamientos.',
                ),
                value: updates.automatic,
                onChanged: updates.busy ? null : updates.setAutomatic,
              ),
              const SizedBox(height: 12),
              Text(
                ios
                    ? 'La IPA se descarga aquí y se verifica. Envíala a Flarestore o guárdala en Archivos para importarla; firma e instala con el mismo identificador para conservar tu biblioteca.'
                    : 'La descarga se realiza aquí. Android te pedirá confirmar la instalación.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    ),
  );
}
