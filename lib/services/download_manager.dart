import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
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

    // 2. Check Global Registry (Fast Path)
    // If we already have this URL downloaded from another tab, use that file.
    final downloadsBox = Hive.box('downloads');
    final existingPath = downloadsBox.get(track.effectiveUrl);

    if (existingPath != null && existingPath is String && File(existingPath).existsSync()) {
       track.localPath = existingPath;
       if (track.isInBox) {
         await track.save();
       }
       onSuccess?.call();
       return;
    }

    if (track.localPath.isNotEmpty && File(track.localPath).existsSync()) {
      onSuccess?.call();
      return; // Already downloaded (Checked object state)
    }

    // 3. Permissions (Android specifically)
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isPermanentlyDenied) {
        onError?.call("Storage permission denied");
        return;
      }
    }

    // 4. Add to Active Set
    _addToActive(track.effectiveUrl);

    try {
      // 5. Determine Path
      final dir = await getApplicationDocumentsDirectory();
      final safeName = track.displayName.replaceAll(RegExp(r'[^\w\s\.-]'), '').trim();
      final savePath = '${dir.path}/$safeName.mp3';

      // 6. Download
      await _dio.download(
        track.effectiveUrl,
        savePath,
        options: Options(receiveTimeout: const Duration(minutes: 10)),
      );

      // 7. Update Track Object AND Global Registry
      final file = File(savePath);
      if (file.existsSync()) {
        // A. Update the specific track instance
        track.localPath = savePath;
        if (track.isInBox) {
          await track.save();
        }

        // B. Update the Global Downloads Registry
        await downloadsBox.put(track.effectiveUrl, savePath);

        onSuccess?.call();
      } else {
        throw Exception("File not found after download");
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.error is SocketException) {
        onError?.call("No Internet Connection");
      } else {
        debugPrint("Download failed for ${track.title}: $e");
        onError?.call("Download Failed");
      }
    } catch (e) {
      debugPrint("Download failed for ${track.title}: $e");
      onError?.call("Download Failed");
    } finally {
      // 8. Remove from Active Set
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