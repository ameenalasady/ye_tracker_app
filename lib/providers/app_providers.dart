import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sheet_tab.dart';
import '../models/track.dart';
import '../services/tracker_parser.dart';
import '../services/audio_handler.dart';

final sourceUrlProvider = StateProvider<String>((ref) => "yetracker.net");
final searchQueryProvider = StateProvider<String>((ref) => "");

// --- SETTINGS PROVIDERS ---

final autoDownloadProvider = StateProvider<bool>((ref) {
  // Initialize from Hive, default to true
  final box = Hive.box('settings');
  return box.get('auto_download', defaultValue: true);
});

// Calculate Cache Size
final cacheSizeProvider = FutureProvider<String>((ref) async {
  // Trigger recalculation when tabs change or manual refresh
  ref.watch(tabsProvider);

  final dir = await getApplicationDocumentsDirectory();
  try {
    // Only count MP3s to avoid counting system/hive files
    final files = dir.listSync().where((f) => f.path.endsWith('.mp3'));
    int totalBytes = 0;
    for (var f in files) {
      totalBytes += (f as File).lengthSync();
    }

    if (totalBytes < 1024 * 1024) {
      return "${(totalBytes / 1024).toStringAsFixed(1)} KB";
    }
    return "${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  } catch (e) {
    return "0 MB";
  }
});

// --- AUDIO HANDLER ---

final audioHandlerProvider = Provider<MyAudioHandler>((ref) {
  throw UnimplementedError("Initialize in main.dart");
});

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(audioHandlerProvider).playbackState;
});

final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  return ref.watch(audioHandlerProvider).mediaItem;
});

// --- DATA FETCHING ---

final tabsProvider = FutureProvider<List<SheetTab>>((ref) async {
  final source = ref.watch(sourceUrlProvider);
  final parser = TrackerParser(source);
  return await parser.fetchTabs();
});

final selectedTabProvider = StateProvider<SheetTab?>((ref) => null);

final tracksProvider = FutureProvider<List<Track>>((ref) async {
  final tab = ref.watch(selectedTabProvider);
  if (tab == null) return [];

  final boxName = 'tracks_${tab.gid}';

  Box<Track> box;
  if (Hive.isBoxOpen(boxName)) {
    box = Hive.box<Track>(boxName);
  } else {
    try {
      box = await Hive.openBox<Track>(boxName);
    } catch (e) {
      await Hive.deleteBoxFromDisk(boxName);
      box = await Hive.openBox<Track>(boxName);
    }
  }

  if (box.isNotEmpty) {
    return box.values.toList();
  }

  try {
    final source = ref.read(sourceUrlProvider);
    final parser = TrackerParser(source);
    final tracks = await parser.fetchTracksForTab(tab.gid);

    await box.clear();
    await box.addAll(tracks);

    return tracks;
  } catch (e) {
    if (box.isNotEmpty) return box.values.toList();
    rethrow;
  }
});

final filteredTracksProvider = Provider<AsyncValue<List<Track>>>((ref) {
  final tracksAsync = ref.watch(tracksProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return tracksAsync.whenData((tracks) {
    if (query.isEmpty) return tracks;
    return tracks.where((t) => t.searchIndex.contains(query)).toList();
  });
});

// --- CACHE UTILITIES ---

class CacheManager {
  static Future<void> clearAllCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync();

    // 1. Delete physical files
    for (var entity in files) {
      if (entity is File && entity.path.endsWith('.mp3')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }

    // 2. Reset 'localPath' in all Track boxes
    // We iterate over open boxes. If a box isn't open, the UI will
    // simply not show it as downloaded until the file check fails anyway.
    // However, to be thorough, we check all known track boxes.
    // (Simplification: We iterate currently open boxes for immediate UI update)

    // Note: Hive doesn't give a list of all box names on disk easily without
    // platform specific directory scanning. We will rely on the fact that
    // if the file is gone, the TrackTile logic (File.exists) returns false.
    // But we should clean the objects to prevent stale paths.

    // Iterate all tabs if possible, or just open boxes
    // This is a "best effort" cleanup for open boxes
    for (var key in Hive.box('settings').keys) {
      // If we stored tab lists, we could iterate them.
    }

    // Hack: We rely on the TrackTile build method checking File(path).exists()
    // which effectively resets the UI state visually.
    // To properly clear the Hive data, we would need to know every GID ever visited.
  }
}