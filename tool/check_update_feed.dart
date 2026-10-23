import 'dart:convert';
import 'dart:io';

import 'package:acrostella_analytics/src/updates/update_source.dart';

/// Manual smoke check using exactly the public transport shipped in the app.
/// No GitHub authentication, Android installation or real videos are involved.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/check_update_feed.dart OUTPUT_DIRECTORY',
    );
    exitCode = 64;
    return;
  }
  final source = GitHubUpdateSource();
  final cancellation = UpdateCancellation();
  final release = await source.latest(cancellation);
  if (release == null) throw StateError('No public release found');
  final file = await source.download(
    release,
    Directory(arguments.single),
    cancellation,
    (_) {},
  );
  stdout.writeln(
    jsonEncode({
      'repository': updateRepository,
      'version': release.versionName,
      'code': release.versionCode,
      'bytes': await file.length(),
      'verified_sha256': release.sha256,
      'path': file.path,
    }),
  );
}
