import 'dart:io';
import 'dart:async';
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

// --- SORTING & FILTERING ---

enum SortOption { defaultOrder, newest, oldest, nameAz, nameZa, shortest, longest }

final sortOptionProvider = StateProvider<SortOption>((ref) => SortOption.defaultOrder);

// Stores which Eras are currently selected. If empty, it assumes "All Eras".
final selectedErasProvider = StateProvider<Set<String>>((ref) => {});

// --- SETTINGS PROVIDERS ---

final autoDownloadProvider = StateProvider<bool>((ref) {
  final box = Hive.box('settings');
  return box.get('auto_download', defaultValue: true);
});

// Calculate Cache Size
final cacheSizeProvider = FutureProvider<String>((ref) async {
  ref.watch(tabsProvider);

  final dir = await getApplicationDocumentsDirectory();
  try {
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

final activeDownloadsProvider = StreamProvider<Set<String>>((ref) {
  final handler = ref.watch(audioHandlerProvider);

  return Stream.multi((controller) {
    void listener() {
      if (!controller.isClosed) {
        controller.add(handler.downloadingTracks.value);
      }
    }
    controller.add(handler.downloadingTracks.value);
    handler.downloadingTracks.addListener(listener);
    controller.onCancel = () {
      handler.downloadingTracks.removeListener(listener);
    };
  });
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

// --- FILTERING LOGIC ---

// Returns a unique list of Eras present in the current loaded tab
final availableErasProvider = Provider<List<String>>((ref) {
  final tracksAsync = ref.watch(tracksProvider);
  return tracksAsync.maybeWhen(
    data: (tracks) {
      // Extract unique non-empty eras
      final eras = tracks.map((t) => t.era.trim()).where((e) => e.isNotEmpty).toSet().toList();
      // Keep them in order of appearance (which usually matches the spreadsheet chronology)
      // or sort them if you prefer alphabetical
      return eras;
    },
    orElse: () => [],
  );
});

final filteredTracksProvider = Provider<AsyncValue<List<Track>>>((ref) {
  final tracksAsync = ref.watch(tracksProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final sortOption = ref.watch(sortOptionProvider);
  final selectedEras = ref.watch(selectedErasProvider);

  return tracksAsync.whenData((tracks) {
    // 1. Basic Validity Filter (Must have length)
    var result = tracks.where((t) => t.length.trim().isNotEmpty).toList();

    // 2. Era Filtering
    if (selectedEras.isNotEmpty) {
      result = result.where((t) => selectedEras.contains(t.era.trim())).toList();
    }

    // 3. Search Filtering
    if (query.isNotEmpty) {
      result = result.where((t) => t.searchIndex.contains(query)).toList();
    }

    // 4. Sorting
    // We create a copy to sort so we don't mutate the original cached list order
    result = List.of(result);

    switch (sortOption) {
      case SortOption.newest:
        // Attempt string sort on ISO dates or similar.
        // Fallback: Use list order if no date, or assume bottom of list is newer if data is chronological
        result.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
        break;
      case SortOption.oldest:
        result.sort((a, b) => a.releaseDate.compareTo(b.releaseDate));
        break;
      case SortOption.nameAz:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOption.nameZa:
        result.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case SortOption.shortest:
        result.sort((a, b) => a.durationInSeconds.compareTo(b.durationInSeconds));
        break;
      case SortOption.longest:
        result.sort((a, b) => b.durationInSeconds.compareTo(a.durationInSeconds));
        break;
      case SortOption.defaultOrder:
      default:
        // Do nothing, keep spreadsheet order
        break;
    }

    return result;
  });
});

// --- CACHE UTILITIES ---

class CacheManager {
  static Future<void> clearAllCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync();

    for (var entity in files) {
      if (entity is File && entity.path.endsWith('.mp3')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }
}