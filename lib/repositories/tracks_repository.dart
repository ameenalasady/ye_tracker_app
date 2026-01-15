import 'package:hive/hive.dart';
import '../models/sheet_tab.dart';
import '../models/track.dart';
import '../services/tracker_parser.dart';

class TracksRepository {
  final TrackerParser _parser;

  TracksRepository({required String sourceUrl}) : _parser = TrackerParser(sourceUrl);

  /// Fetches the list of tabs (Eras) from the network.
  Future<List<SheetTab>> fetchTabs() async {
    return await _parser.fetchTabs();
  }

  /// Tries to load tracks from local Hive box.
  /// If empty, fetches from network and saves to Hive.
  Future<List<Track>> getTracksForTab(SheetTab tab) async {
    final box = await _openBoxForTab(tab);

    if (box.isNotEmpty) {
      return box.values.toList();
    }

    try {
      // Fetch from network
      final tracks = await _parser.fetchTracksForTab(tab.gid);

      // Save to local cache
      await box.clear();
      await box.addAll(tracks);

      return tracks;
    } catch (e) {
      // If network fails but we have (somehow) data, return it.
      if (box.isNotEmpty) return box.values.toList();
      rethrow;
    }
  }

  /// Explicitly clears the local cache for a specific tab.
  /// Used for "Pull to Refresh".
  Future<void> clearLocalCache(SheetTab tab) async {
    final box = await _openBoxForTab(tab);
    await box.clear();
  }

  /// Helper to manage box lifecycle
  Future<Box<Track>> _openBoxForTab(SheetTab tab) async {
    final boxName = 'tracks_${tab.gid}';
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<Track>(boxName);
    } else {
      try {
        return await Hive.openBox<Track>(boxName);
      } catch (e) {
        // Handle corrupted box by deleting and recreating
        await Hive.deleteBoxFromDisk(boxName);
        return await Hive.openBox<Track>(boxName);
      }
    }
  }
}