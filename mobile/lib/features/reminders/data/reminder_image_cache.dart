import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads reminder photos into app cache so AlarmManager can still show
/// them after signed storage URLs expire.
class ReminderImageCache {
  ReminderImageCache({this.client, this.directory});

  final http.Client? client;
  final Directory? directory;

  static const _maxAge = Duration(days: 7);

  Future<String?> cacheUrl({
    required String reminderId,
    required String url,
  }) async {
    if (url.trim().isEmpty) return null;
    try {
      final dir = await _dir();
      final file = File('${dir.path}/$reminderId.jpg');
      if (file.existsSync()) {
        final age = DateTime.now().difference(file.lastModifiedSync());
        if (age < _maxAge && file.lengthSync() > 0) {
          return file.path;
        }
      }
      final httpClient = client ?? http.Client();
      final owned = client == null;
      try {
        final response = await httpClient
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          return file.existsSync() ? file.path : null;
        }
        await file.writeAsBytes(response.bodyBytes, flush: true);
        return file.path;
      } finally {
        if (owned) httpClient.close();
      }
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _dir() async {
    final override = directory;
    if (override != null) {
      await override.create(recursive: true);
      return override;
    }
    final root = await getApplicationCacheDirectory();
    final dir = Directory('${root.path}/reminder_photos');
    await dir.create(recursive: true);
    return dir;
  }
}
