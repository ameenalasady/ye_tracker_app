import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/sheet_tab.dart';
import '../models/track.dart';
import '../services/tracker_parser.dart';
import '../services/audio_handler.dart';

final sourceUrlProvider = StateProvider<String>((ref) => "yetracker.net");
final searchQueryProvider = StateProvider<String>((ref) => "");

// Audio Handler Injection
final audioHandlerProvider = Provider<MyAudioHandler>((ref) {
  throw UnimplementedError("Initialize in main.dart");
});

// Stream Providers for Real-time UI updates
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(audioHandlerProvider).playbackState;
});

final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  return ref.watch(audioHandlerProvider).mediaItem;
});

// Fetch Tabs
final tabsProvider = FutureProvider<List<SheetTab>>((ref) async {
  final source = ref.watch(sourceUrlProvider);
  final parser = TrackerParser(source);
  return await parser.fetchTabs();
});

// Currently Selected Tab
final selectedTabProvider = StateProvider<SheetTab?>((ref) => null);

// Fetch Tracks for Selected Tab
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