import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/track.dart';

class DownloadManager extends ValueNotifier<Set<String>> {
  final Dio _dio = Dio();

  DownloadManager() : super({});

  /// Returns true if the track is currently downloading
  bool isDownloading(String url) => value.contains(url);

  /// Downloads a track, saves it to storage, and updates the Hive object.
  Future<void> downloadTrack(Track track, {VoidCallback? onSuccess, Function(String)? onError}) async {
    // 1. Validation
    if (track.effectiveUrl.isEmpty) {
      onError?.call("Invalid URL");
      return;
    }
    if (value.contains(track.effectiveUrl)) return; // Already downloading
    if (track.localPath.isNotEmpty && File(track.localPath).existsSync()) {
      onSuccess?.call();
      return; // Already downloaded
    }

    // 2. Permissions (Android specifically)
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      // On Android 13+, storage permissions are granular (audio, images, etc).
      // Usually getApplicationDocumentsDirectory doesn't need explicit storage permission
      // for internal app storage, but if you change to external, you need it.
      // Keeping generic check for safety.
      if (status.isPermanentlyDenied) {
        onError?.call("Storage permission denied");
        return;
      }
    }

    // 3. Add to Active Set
    _addToActive(track.effectiveUrl);

    try {
      // 4. Determine Path
      final dir = await getApplicationDocumentsDirectory();
      final safeName = track.displayName.replaceAll(RegExp(r'[^\w\s\.-]'), '').trim();
      final savePath = '${dir.path}/$safeName.mp3';

      // 5. Download
      await _dio.download(
        track.effectiveUrl,
        savePath,
        options: Options(receiveTimeout: const Duration(minutes: 10)),
      );

      // 6. Update Track Object (Hive)
      final file = File(savePath);
      if (file.existsSync()) {
        track.localPath = savePath;
        if (track.isInBox) {
          await track.save();
        }
        onSuccess?.call();
      } else {
        throw Exception("File not found after download");
      }
    } catch (e) {
      debugPrint("Download failed for ${track.title}: $e");
      onError?.call("Download Failed");
    } finally {
      // 7. Remove from Active Set
      _removeFromActive(track.effectiveUrl);
    }
  }

  void _addToActive(String url) {
    final newSet = Set<String>.from(value);
    newSet.add(url);
    value = newSet;
  }

  void _removeFromActive(String url) {
    final newSet = Set<String>.from(value);
    newSet.remove(url);
    value = newSet;
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}