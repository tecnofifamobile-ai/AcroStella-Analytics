import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'update_controller.dart';
import 'update_source.dart';

/// Downloads are authenticated by the publisher's hash, never automatically
/// signed/installed. User certificates remain exclusively in their signer.
class IosUpdateInstaller implements UpdateInstaller {
  IosUpdateInstaller({this.share});
  final Future<void> Function(File)? share;

  @override
  Future<InstalledApp> installed() async {
    final info = await PackageInfo.fromPlatform();
    final os = RegExp(r'\d+\.\d+(?:\.\d+)?')
        .firstMatch(Platform.operatingSystemVersion)
        ?.group(0);
    return InstalledApp(
      int.parse(info.buildNumber),
      info.version,
      0,
      true,
      platform: UpdatePlatform.ios,
      osVersion: os,
    );
  }

  @override
  Future<void> verify(File file, UpdateRelease release) async {
    if (release.platform != UpdatePlatform.ios ||
        !file.path.endsWith('.ipa') ||
        await file.length() != release.bytes ||
        (await sha256.bind(file.openRead()).first).toString() !=
            release.sha256) {
      throw const UpdateFailure(
        'La IPA ya no coincide con la descarga publicada.',
      );
    }
  }

  @override
  Future<void> install(File file, UpdateRelease release) async {
    await verify(file, release);
    if (share != null) {
      await share!(file);
      return;
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/octet-stream')],
        sharePositionOrigin: Rect.fromLTWH(
          size.width / 2,
          size.height / 2,
          1,
          1,
        ),
      ),
    );
  }

  @override
  Future<void> openPermission() async {
    /* Signing happens in the chosen app. */
  }
}
