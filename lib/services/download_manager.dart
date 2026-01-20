import 'dart:collection';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/track.dart';

enum DownloadStatus {
  queued,
  connecting,
  downloading,
  completed,
  failed,
  canceled,
}

class DownloadTask {
  final Track track;
  final String id; // track.effectiveUrl
  DownloadStatus status;
  double progress; // 0.0 to 1.0
  String statusMessage;

  DownloadTask({
    required this.track,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.statusMessage = "Queued",
  }) : id = track.effectiveUrl;
}

class DownloadManager extends ChangeNotifier {
  final Dio _dio = Dio();

  // The master list of all tasks (active + queued)
  final List<DownloadTask> _tasks = [];

  // Expose tasks as an unmodifiable list for UI
  List<DownloadTask> get tasks => UnmodifiableListView(_tasks);

  // Helper to check if a specific URL is in the list
  bool isDownloading(String url) => _tasks.any(
    (t) =>
        t.id == url &&
        t.status != DownloadStatus.completed &&
        t.status != DownloadStatus.failed,
  );

  // Helper for TrackTiles to just check existence
  Set<String> get activeUrlSet => _tasks
      .where(
        (t) =>
            t.status != DownloadStatus.completed &&
            t.status != DownloadStatus.failed,
      )
      .map((t) => t.id)
      .toSet();

  Future<void> downloadTrack(
    Track track, {
    VoidCallback? onSuccess,
    Function(String)? onError,
  }) async {
    // 1. Validation
    if (track.effectiveUrl.isEmpty) {
      onError?.call("Invalid URL");
      return;
    }

    // 2. Check if already in queue/downloading (The Gatekeeper)
    // This check prevents duplicates.
    if (isDownloading(track.effectiveUrl)) return;

    // 3. Check Existence (Fast Path)
    // If we already have the file, we don't need to create a task at all.
    final downloadsBox = Hive.box('downloads');
    final existingPath = downloadsBox.get(track.effectiveUrl);

    if (existingPath != null &&
        existingPath is String &&
        File(existingPath).existsSync()) {
      track.localPath = existingPath;
      if (track.isInBox) await track.save();
      onSuccess?.call();
      return;
    }

    if (track.localPath.isNotEmpty && File(track.localPath).existsSync()) {
      onSuccess?.call();
      return;
    }

    // 4. Create Task and Add to List IMMEDIATELY
    // FIX: We add the task *before* awaiting permissions.
    // This acts as a synchronous lock. Any subsequent calls for this URL
    // will now fail the `isDownloading` check at step 2.
    final task = DownloadTask(track: track);
    _tasks.add(task);
    notifyListeners(); // Update UI immediately

    // 5. Permissions
    if (Platform.isAndroid) {
      // This await caused the race condition previously
      final status = await Permission.storage.request();
      if (status.isPermanentlyDenied) {
        // If permission fails, we must unlock the queue by removing the task
        _tasks.remove(task);
        notifyListeners();
        onError?.call("Storage permission denied");
        return;
      }
    }

    // 6. Process Queue
    _processQueue();
  }

  void _processQueue() async {
    // Get setting for concurrency
    final settingsBox = Hive.box('settings');
    final int maxConcurrent = settingsBox.get(
      'max_concurrent_downloads',
      defaultValue: 2,
    );

    // Count how many are currently running
    final runningCount = _tasks
        .where(
          (t) =>
              t.status == DownloadStatus.connecting ||
              t.status == DownloadStatus.downloading,
        )
        .length;

    if (runningCount >= maxConcurrent) return;

    // Find next queued item
    try {
      final nextTask = _tasks.firstWhere(
        (t) => t.status == DownloadStatus.queued,
      );
      _startDownload(nextTask);

      // If we still have room, recurse lightly to fill slots
      if (runningCount + 1 < maxConcurrent) {
        _processQueue();
      }
    } catch (e) {
      // No queued items found, we are done.
    }
  }

  Future<void> _startDownload(DownloadTask task) async {
    task.status = DownloadStatus.connecting;
    task.statusMessage = "Connecting...";
    notifyListeners();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = task.track.displayName
          .replaceAll(RegExp(r'[^\w\s\.-]'), '')
          .trim();
      final savePath = '${dir.path}/$safeName.mp3';

      await _dio.download(
        task.track.effectiveUrl,
        savePath,
        options: Options(receiveTimeout: const Duration(minutes: 10)),
        onReceiveProgress: (received, total) {
          task.status = DownloadStatus.downloading;
          if (total != -1) {
            task.progress = received / total;
            task.statusMessage = "${(task.progress * 100).toStringAsFixed(0)}%";
          } else {
            // Indeterminate
            task.statusMessage = "Downloading...";
          }
          notifyListeners();
        },
      );

      final file = File(savePath);
      if (file.existsSync()) {
        task.track.localPath = savePath;
        if (task.track.isInBox) await task.track.save();

        final downloadsBox = Hive.box('downloads');
        await downloadsBox.put(task.track.effectiveUrl, savePath);

        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        task.statusMessage = "Done";
      } else {
        throw Exception("File missing");
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.statusMessage = "Failed";
      debugPrint("Download Error: $e");
    } finally {
      notifyListeners();
      _processQueue();

      // Cleanup completed tasks after 2 seconds to keep list clean
      if (task.status == DownloadStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          _tasks.remove(task);
          notifyListeners();
        });
      }
    }
  }

  // Called when settings change to potentially start more downloads
  void retryQueue() {
    _processQueue();
  }
}