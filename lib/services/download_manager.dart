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
  DownloadTask({
    required this.track,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.statusMessage = 'Queued',
  }) : id = track.effectiveUrl;
  final Track track;
  final String id; // track.effectiveUrl
  DownloadStatus status;
  double progress; // 0.0 to 1.0
  String statusMessage;
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

  /// Checks if the device has an active internet connection using dart:io
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> downloadTrack(
    Track track, {
    VoidCallback? onSuccess,
    Function(String)? onError,
  }) async {
    // 1. Validation
    if (track.effectiveUrl.isEmpty) {
      onError?.call('Invalid URL');
      return;
    }

    // 2. Check if already in queue/downloading (The Gatekeeper)
    // This check prevents duplicates.
    if (isDownloading(track.effectiveUrl)) return;

    // 3. Check Existence (Fast Path) - Works Offline
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

    // 4. Create Task and Add to List IMMEDIATELY (Synchronous Lock)
    // We add it now so that subsequent calls to isDownloading() return true immediately.
    final task = DownloadTask(track: track);
    _tasks.add(task);
    notifyListeners();

    // 5. Connectivity Check (Async)
    // Only check for internet if we actually need to download the file.
    final isOnline = await _hasInternetConnection();
    if (!isOnline) {
      // If checks fail, we must unlock the queue by removing the task
      _tasks.remove(task);
      notifyListeners();
      onError?.call('No Internet Connection');
      return;
    }

    // 6. Permissions (Async)
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isPermanentlyDenied) {
        _tasks.remove(task);
        notifyListeners();
        onError?.call('Storage permission denied');
        return;
      }
    }

    // 7. Process Queue
    _processQueue();
  }

  void _processQueue() {
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

    // If we are at capacity, do nothing.
    if (runningCount >= maxConcurrent) return;

    // Calculate how many slots are free
    final slotsAvailable = maxConcurrent - runningCount;
    if (slotsAvailable <= 0) return;

    // Find the next N queued tasks
    final tasksToStart = _tasks
        .where((t) => t.status == DownloadStatus.queued)
        .take(slotsAvailable)
        .toList();

    // Start them iteratively. We do NOT await here.
    // This allows _processQueue to exit immediately, unwinding the stack.
    for (final task in tasksToStart) {
      _startDownload(task);
    }
  }

  Future<void> _startDownload(DownloadTask task) async {
    task.status = DownloadStatus.connecting;
    task.statusMessage = 'Connecting...';
    // Notify to update UI (spinner/status)
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
            task.statusMessage = '${(task.progress * 100).toStringAsFixed(0)}%';
          } else {
            // Indeterminate
            task.statusMessage = 'Downloading...';
          }
          // We call notifyListeners inside the progress callback
          // Note: In high-frequency updates, you might want to throttle this,
          // but for now, it ensures the UI bar moves smoothly.
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
        task.statusMessage = 'Done';
      } else {
        throw Exception('File missing');
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.statusMessage = 'Failed';
      debugPrint('Download Error: $e');
    } finally {
      notifyListeners();

      // Trigger the queue again to pick up the next item.
      // Using Future.microtask ensures this runs on the next event loop tick,
      // preventing stack depth accumulation (Stack Overflow fix).
      Future.microtask(() => _processQueue());

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
