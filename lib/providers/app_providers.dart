import 'dart:io';
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/playlist.dart';
import '../models/sheet_tab.dart';
import '../models/track.dart';
import '../repositories/tracks_repository.dart'; // Import Repository
import '../services/audio_handler.dart';
import '../services/download_manager.dart';

final sourceUrlProvider = StateProvider<String>((ref) => "yetracker.net");
final searchQueryProvider = StateProvider<String>((ref) => "");

// --- REPOSITORY PROVIDER ---
final tracksRepositoryProvider = Provider<TracksRepository>((ref) {
  final sourceUrl = ref.watch(sourceUrlProvider);
  return TracksRepository(sourceUrl: sourceUrl);
});

// --- SORTING & FILTERING ---
enum SortOption { defaultOrder, newest, oldest, nameAz, nameZa, shortest, longest }
final sortOptionProvider = StateProvider<SortOption>((ref) => SortOption.defaultOrder);
final selectedErasProvider = StateProvider<Set<String>>((ref) => {});

// --- SETTINGS PROVIDERS ---
final autoDownloadProvider = StateNotifierProvider<AutoDownloadNotifier, bool>((ref) {
  return AutoDownloadNotifier();
});

class AutoDownloadNotifier extends StateNotifier<bool> {
  AutoDownloadNotifier() : super(true) {
    _load();
  }

  void _load() {
    // Box is opened in main.dart before app starts, so this is safe
    final box = Hive.box('settings');
    state = box.get('auto_download', defaultValue: true);
  }

  void set(bool value) {
    state = value;
    Hive.box('settings').put('auto_download', value);
  }
}

final cacheSizeProvider = FutureProvider<String>((ref) async {
  // Watch tabs to recalculate when tabs change/refresh
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

// --- DOWNLOAD MANAGER ---
final downloadManagerProvider = Provider<DownloadManager>((ref) {
  throw UnimplementedError("Initialize in main.dart");
});

final activeDownloadsProvider = StreamProvider<Set<String>>((ref) {
  final manager = ref.watch(downloadManagerProvider);
  return Stream.multi((controller) {
    void listener() {
      if (!controller.isClosed) controller.add(manager.value);
    }
    controller.add(manager.value);
    manager.addListener(listener);
    controller.onCancel = () => manager.removeListener(listener);
  });
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

final queueProvider = StreamProvider<List<MediaItem>>((ref) {
  return ref.watch(audioHandlerProvider).queue;
});

final shuffleModeProvider = StreamProvider<AudioServiceShuffleMode>((ref) {
  return ref.watch(audioHandlerProvider).playbackState
      .map((state) => state.shuffleMode)
      .distinct();
});

final repeatModeProvider = StreamProvider<AudioServiceRepeatMode>((ref) {
  return ref.watch(audioHandlerProvider).playbackState
      .map((state) => state.repeatMode)
      .distinct();
});

// --- DATA FETCHING (REFACTORED) ---

final tabsProvider = FutureProvider<List<SheetTab>>((ref) async {
  final repository = ref.watch(tracksRepositoryProvider);
  return await repository.fetchTabs();
});

final selectedTabProvider = StateProvider<SheetTab?>((ref) => null);

final tracksProvider = FutureProvider<List<Track>>((ref) async {
  final tab = ref.watch(selectedTabProvider);
  if (tab == null) return [];

  final repository = ref.watch(tracksRepositoryProvider);
  return await repository.getTracksForTab(tab);
});

// --- PLAYLISTS PROVIDER ---
final playlistsProvider = StateNotifierProvider<PlaylistsNotifier, List<Playlist>>((ref) {
  return PlaylistsNotifier();
});

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  late Box<Playlist> _box;

  PlaylistsNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    if (!Hive.isBoxOpen('playlists')) {
      _box = await Hive.openBox<Playlist>('playlists');
    } else {
      _box = Hive.box<Playlist>('playlists');
    }
    _box.listenable().addListener(() {
      state = _box.values.toList();
    });
    state = _box.values.toList();
  }

  Future<void> createPlaylist(String name) async {
    final newPlaylist = Playlist(name: name, tracks: []);
    await _box.add(newPlaylist);
    // State updates automatically via listener
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    await playlist.delete();
  }

  Future<void> addTrackToPlaylist(Playlist playlist, Track track) async {
    // Only add if not already present
    if (!playlist.tracks.any((t) => t == track)) {
      playlist.tracks.add(track);
      await playlist.save();
    }
  }

  Future<void> removeTrackFromPlaylist(Playlist playlist, Track track) async {
    playlist.tracks.removeWhere((t) => t == track);
    await playlist.save();
  }
}

// --- FILTERING LOGIC ---
final availableErasProvider = Provider<List<String>>((ref) {
  final tracksAsync = ref.watch(tracksProvider);
  return tracksAsync.maybeWhen(
    data: (tracks) {
      return tracks
          .map((t) => t.era.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
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
    var result = tracks.where((t) => t.length.trim().isNotEmpty).toList();

    if (selectedEras.isNotEmpty) {
      result = result.where((t) => selectedEras.contains(t.era.trim())).toList();
    }

    if (query.isNotEmpty) {
      result = result.where((t) => t.searchIndex.contains(query)).toList();
    }

    // Create a copy to sort
    result = List.of(result);

    switch (sortOption) {
      case SortOption.newest:
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
      break;
    }

    return result;
  });
});

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

    final downloadsBox = Hive.box('downloads');
    await downloadsBox.clear();
  }
}