import 'dart:io';
import 'package:hive/hive.dart';
import '../models/sheet_tab.dart';
import '../models/track.dart';
import '../services/tracker_parser.dart';

class TracksRepository {
  final TrackerParser _parser;

  TracksRepository({required String sourceUrl}) : _parser = TrackerParser(sourceUrl);

  /// Fetches the list of tabs (Eras).
  /// Implemented Network-First, Cache-Fallback strategy.
  Future<List<SheetTab>> fetchTabs() async {
    final box = Hive.box<SheetTab>('tabs');

    try {
      // 1. Try Network
      final tabs = await _parser.fetchTabs();

      // 2. If successful, update cache
      await box.clear();
      await box.addAll(tabs);

      return tabs;
    } catch (e) {
      // 3. If Network fails, check cache
      if (box.isNotEmpty) {
        return box.values.toList();
      }
      // 4. If no cache and no network, rethrow
      rethrow;
    }
  }

  /// Tries to load tracks from local Hive box.
  /// If empty, fetches from network and saves to Hive.
  Future<List<Track>> getTracksForTab(SheetTab tab) async {
    final box = await _openBoxForTab(tab);

    // FIX: If we have data, return it immediately (Cache First).
    // This ensures offline mode works instantly.
    // To get new data, the user must use "Pull to Refresh" in the UI,
    // which calls clearLocalCache().
    if (box.isNotEmpty) {
      return box.values.toList();
    }

    try {
      // Fetch from network if cache is empty
      final tracks = await _parser.fetchTracksForTab(tab.gid);

      // --- FIX: Restore Download State ---
      // Cross-reference with the Global Downloads Registry.
      // If the URL exists in 'downloads' box and the file exists,
      // set the localPath on this new Track object.
      final downloadsBox = Hive.box('downloads');

      for (var track in tracks) {
        final savedPath = downloadsBox.get(track.effectiveUrl);
        if (savedPath != null && savedPath is String) {
          if (File(savedPath).existsSync()) {
            track.localPath = savedPath;
          } else {
            // File was deleted manually from disk? Remove from registry.
            downloadsBox.delete(track.effectiveUrl);
          }
        }
      }

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