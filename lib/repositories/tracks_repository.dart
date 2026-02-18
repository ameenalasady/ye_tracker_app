import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // Import Cache Manager
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
      rethrow;
    }
  }

  /// Tries to load tracks from local Hive box.
  /// If empty, fetches from network and saves to Hive.
  Future<List<Track>> getTracksForTab(SheetTab tab) async {
    final box = await _openBoxForTab(tab);

    // Cache First: If we have data, return it immediately to be snappy.
    if (box.isNotEmpty) {
      // Trigger a background refresh of images even on cache hit
      _backgroundPrefetchImages(box.values.toList());
      return box.values.toList();
    }

    try {
      // Fetch from network
      final tracks = await _parser.fetchTracksForTab(tab.gid);

      final downloadsBox = Hive.box('downloads');
      final eraImagesBox = Hive.box('era_images');

      // --- NEW: Harvest & Prefetch Strategy ---
      // 1. Harvest all Era->Image mappings found in this tab
      final Map<String, String> foundEraImages = {};
      final Set<String> urlsToPrefetch = {};

      for (final track in tracks) {
        if (track.albumArtUrl.isNotEmpty) {
          foundEraImages[track.era] = track.albumArtUrl;
          urlsToPrefetch.add(track.albumArtUrl);
        }
      }

      // 2. Save mappings to Hive immediately
      if (foundEraImages.isNotEmpty) {
        await eraImagesBox.putAll(foundEraImages);
      }

      // 3. Restore Download State (Local Paths)
      for (final track in tracks) {
        final savedPath = downloadsBox.get(track.effectiveUrl);
        if (savedPath != null && savedPath is String) {
          if (File(savedPath).existsSync()) {
            track.localPath = savedPath;
          } else {
            downloadsBox.delete(track.effectiveUrl);
          }
        }
      }

      // 4. Save tracks to local cache
      await box.clear();
      await box.addAll(tracks);

      // 5. Fire-and-forget: Warm up the image cache
      // We don't await this so the UI renders immediately
      _prefetchImageBinaries(urlsToPrefetch);

      return tracks;
    } catch (e) {
      if (box.isNotEmpty) return box.values.toList();
      rethrow;
    }
  }

  /// Extracts images from an existing list and tries to cache them.
  void _backgroundPrefetchImages(List<Track> tracks) {
    final Set<String> urls = {};
    for (final t in tracks) {
      if (t.effectiveAlbumArt.isNotEmpty) {
        urls.add(t.effectiveAlbumArt);
      }
    }
    _prefetchImageBinaries(urls);
  }

  /// Uses FlutterCacheManager to download images to disk in the background.
  /// This ensures that when the user scrolls, the file is already on the FS.
  Future<void> _prefetchImageBinaries(Set<String> urls) async {
    final cacheManager = DefaultCacheManager();
    for (final url in urls) {
      try {
        // We use downloadFile which checks cache first, then downloads if needed.
        // We don't do anything with the file info, just ensure it exists.
        cacheManager.getSingleFile(url, headers: Track.imageHeaders).then((_) {
          // Success, image is cached.
        }).catchError((_) {
          // Silent failure is fine for prefetching
        });
      } catch (_) {}
    }
  }

  /// Explicitly clears the local cache for a specific tab.
  Future<void> clearLocalCache(SheetTab tab) async {
    final box = await _openBoxForTab(tab);
    await box.clear();
  }

  Future<void> clearAllCaches(List<SheetTab> tabs) async {
    for (final tab in tabs) {
      await clearLocalCache(tab);
    }
  }

  Future<Box<Track>> _openBoxForTab(SheetTab tab) async {
    final boxName = 'tracks_${tab.gid}';
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<Track>(boxName);
    } else {
      try {
        return await Hive.openBox<Track>(boxName);
      } catch (e) {
        await Hive.deleteBoxFromDisk(boxName);
        return Hive.openBox<Track>(boxName);
      }
    }
  }
}
