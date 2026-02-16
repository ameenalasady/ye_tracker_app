import 'dart:io';
import 'package:hive/hive.dart';
import '../models/sheet_tab.dart';
import '../models/track.dart';
import '../services/tracker_parser.dart';

class TracksRepository {

  TracksRepository({required String sourceUrl})
    : _parser = TrackerParser(sourceUrl);
  final TrackerParser _parser;

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
    if (box.isNotEmpty) {
      return box.values.toList();
    }

    try {
      // Fetch from network if cache is empty
      final tracks = await _parser.fetchTracksForTab(tab.gid);

      final downloadsBox = Hive.box('downloads');
      final eraImagesBox = Hive.box('era_images'); // Access global era images

      // --- NEW: Harvest & Apply Era Images ---
      // 1. Harvest: If a track has an image, save it to the global era_images box
      for (final track in tracks) {
        if (track.albumArtUrl.isNotEmpty) {
          eraImagesBox.put(track.era, track.albumArtUrl);
        }
      }

      for (final track in tracks) {
        // --- Restore Download State ---
        final savedPath = downloadsBox.get(track.effectiveUrl);
        if (savedPath != null && savedPath is String) {
          if (File(savedPath).existsSync()) {
            track.localPath = savedPath;
          } else {
            downloadsBox.delete(track.effectiveUrl);
          }
        }

        // --- Apply Global Era Image if missing ---
        // (Note: track.effectiveAlbumArt handles this dynamically, but saving it here
        // helps if we export the data later, though strictly not necessary with the getter)
        if (track.albumArtUrl.isEmpty) {
          // We don't overwrite the field because it's final,
          // but the UI will use the getter 'effectiveAlbumArt' which checks the box.
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
        return Hive.openBox<Track>(boxName);
      }
    }
  }
}
