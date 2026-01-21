import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'download_manager.dart'; // Import

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final DownloadManager downloadManager; // Dependency Injection

  // Internal cache to map Media IDs (URIs) back to Track objects.
  final Map<String, Track> _trackCache = {};

  ConcatenatingAudioSource? _playlist;

  // Constructor accepts DownloadManager
  MyAudioHandler(this.downloadManager) {
    _loadEmptyPlaylist();
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenToPlaybackState();
  }

  Future<void> _loadEmptyPlaylist() async {
    try {
      _playlist = ConcatenatingAudioSource(children: []);
      await _player.setAudioSource(_playlist!);
    } catch (e) {
      debugPrint("Error loading empty playlist: $e");
    }
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;

      // Standard controls: Previous, Play/Pause, Next
      final controls = [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ];

      playbackState.add(
        playbackState.value.copyWith(
          controls: controls,
          androidCompactActionIndices: const [0, 1, 2],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
          shuffleMode: _player.shuffleModeEnabled
              ? AudioServiceShuffleMode.all
              : AudioServiceShuffleMode.none,
          repeatMode: const {
            LoopMode.off: AudioServiceRepeatMode.none,
            LoopMode.one: AudioServiceRepeatMode.one,
            LoopMode.all: AudioServiceRepeatMode.all,
          }[_player.loopMode]!,
        ),
      );
    });
  }

  void _listenToPlaybackState() {
    // 1. Current Index Changes
    _player.currentIndexStream.listen((index) {
      if (index != null && _playlist != null && index < _playlist!.length) {
        final source = _playlist!.children[index] as UriAudioSource;
        final item = source.tag as MediaItem;

        mediaItem.add(item);

        // Trigger Preloading/Downloading logic
        _schedulePreload();
      }
    });

    // 2. Shuffle Mode Changes (Recalculate "next" songs)
    _player.shuffleModeEnabledStream.listen((enabled) {
      // Small delay to ensure just_audio updates effectiveIndices
      Future.delayed(const Duration(milliseconds: 100), () {
        _schedulePreload();
      });
    });

    // 3. Duration & Queue Updates
    _player.durationStream.listen((duration) {
      final currentItem = mediaItem.value;
      if (currentItem != null && duration != null) {
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
    });

    _player.sequenceStateStream.listen((sequenceState) {
      if (sequenceState == null) return;
      final sequence = sequenceState.effectiveSequence;
      final newQueue = sequence.map((source) {
        return source.tag as MediaItem;
      }).toList();
      queue.add(newQueue);

      // Trigger preload when the sequence is fully loaded.
      // We rely on explicit calls in move/remove as well, but this covers
      // initial loads or external changes.
      _schedulePreload();
    });
  }

  /// Calculates the next tracks in the queue (respecting shuffle)
  /// and triggers downloads if Auto-Download is enabled.
  void _schedulePreload() {
    if (_playlist == null) return;

    // 1. Get Settings
    final settingsBox = Hive.box('settings');
    final bool autoDownload = settingsBox.get(
      'auto_download',
      defaultValue: true,
    );
    final int preloadCount = settingsBox.get('preload_count', defaultValue: 1);

    // 2. Get Current State
    final indices = _player.effectiveIndices; // This respects shuffle!
    final currentIndex = _player.currentIndex;

    if (indices == null || currentIndex == null) return;

    // 3. Find current position in the effective list
    final currentEffectivePos = indices.indexOf(currentIndex);
    if (currentEffectivePos == -1) return;

    // 4. Download Current Song (Priority)
    if (autoDownload) {
      _downloadByIndex(currentIndex);
    }

    // 5. Preload/Download Next Songs
    for (int i = 1; i <= preloadCount; i++) {
      // Check bounds
      if (currentEffectivePos + i >= indices.length) break;

      final nextIndex = indices[currentEffectivePos + i];

      if (autoDownload) {
        // If auto-download is ON, we save to disk.
        _downloadByIndex(nextIndex);
      } else {
        // If auto-download is OFF, just_audio automatically buffers the
        // immediate next item.
      }
    }
  }

  void _downloadByIndex(int index) {
    if (_playlist == null || index >= _playlist!.length) return;

    final source = _playlist!.children[index] as UriAudioSource;
    final item = source.tag as MediaItem;

    // Retrieve Track from our local cache using the ID
    final track = _trackCache[item.id];

    if (track != null) {
      downloadManager.downloadTrack(track);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < queue.value.length) {
      final targetItem = queue.value[index];
      if (_playlist != null) {
        final rawIndex = _playlist!.children.indexWhere(
          (s) => (s as UriAudioSource).tag == targetItem,
        );
        if (rawIndex != -1) {
          _player.seek(Duration.zero, index: rawIndex);
          mediaItem.add(targetItem);
        }
      }
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    if (enabled) {
      await _player.shuffle();
    }
    await _player.setShuffleModeEnabled(enabled);

    playbackState.add(
      playbackState.value.copyWith(
        shuffleMode: shuffleMode,
        updatePosition: _player.position,
      ),
    );
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = {
      AudioServiceRepeatMode.none: LoopMode.off,
      AudioServiceRepeatMode.one: LoopMode.one,
      AudioServiceRepeatMode.all: LoopMode.all,
    }[repeatMode]!;
    await _player.setLoopMode(loopMode);

    playbackState.add(
      playbackState.value.copyWith(
        repeatMode: repeatMode,
        updatePosition: _player.position,
      ),
    );
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final audioSource = _createAudioSource(mediaItem);
    await _playlist?.add(audioSource);
    // Trigger preload in case the added item falls within the preload window
    _schedulePreload();
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (_playlist != null && index < queue.value.length) {
      final targetItem = queue.value[index];
      final rawIndex = _playlist!.children.indexWhere(
        (s) => (s as UriAudioSource).tag == targetItem,
      );
      if (rawIndex != -1) {
        await _playlist!.removeAt(rawIndex);
        // FIX: Trigger preload immediately after removal.
        // If we remove the "Up Next" song, the one after it becomes the new "Next"
        // and needs to be downloaded.
        _schedulePreload();
      }
    }
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    if (!_player.shuffleModeEnabled) {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      await _playlist?.move(oldIndex, newIndex);
      // FIX: Trigger preload immediately after move.
      // This ensures if a song is dragged into the "Up Next" slot or within
      // the preload window, it gets downloaded immediately.
      _schedulePreload();
    }
  }

  Future<void> playPlaylist(List<Track> tracks, int initialIndex) async {
    if (tracks.isEmpty) return;
    final items = tracks.map((track) => _createMediaItem(track)).toList();

    queue.add(items);
    if (initialIndex < items.length) {
      mediaItem.add(items[initialIndex]);
    }

    final audioSources = items.map((item) {
      return _createAudioSource(item);
    }).toList();

    _playlist = ConcatenatingAudioSource(children: audioSources);

    try {
      await _player.setAudioSource(_playlist!, initialIndex: initialIndex);
      // Explicitly schedule preload after source setup
      _schedulePreload();
      play();
    } catch (e) {
      debugPrint("Error playing playlist: $e");
    }
  }

  Future<void> playTrack(Track track) async {
    await playPlaylist([track], 0);
  }

  AudioSource _createAudioSource(MediaItem item) {
    // Retrieve from cache
    final track = _trackCache[item.id];

    // Fallback if track not found
    if (track == null) {
      return AudioSource.uri(Uri.parse(item.id), tag: item);
    }

    String uri = track.effectiveUrl;

    // 1. Check Local Object
    bool isLocal =
        track.localPath.isNotEmpty && File(track.localPath).existsSync();

    // 2. Fallback: Check Global Registry
    if (!isLocal) {
      final downloadsBox = Hive.box('downloads');
      final globalPath = downloadsBox.get(track.effectiveUrl);
      if (globalPath != null && File(globalPath).existsSync()) {
        uri = globalPath;
        isLocal = true;
      }
    } else {
      uri = track.localPath;
    }

    return AudioSource.uri(isLocal ? Uri.file(uri) : Uri.parse(uri), tag: item);
  }

  MediaItem _createMediaItem(Track track) {
    String uri = track.effectiveUrl;

    // 1. Check Local Object
    if (track.localPath.isNotEmpty && File(track.localPath).existsSync()) {
      uri = track.localPath;
    } else {
      // 2. Fallback: Check Global Registry
      final downloadsBox = Hive.box('downloads');
      final globalPath = downloadsBox.get(track.effectiveUrl);
      if (globalPath != null && File(globalPath).existsSync()) {
        uri = globalPath;
      }
    }

    // Store track in local cache using the specific URI we decided on (Network or Local)
    _trackCache[uri] = track;
    // Also store by effectiveUrl to be safe for reverse lookups if needed
    _trackCache[track.effectiveUrl] = track;

    // Use effectiveAlbumArt to check global store
    final artUrl = track.effectiveAlbumArt;

    return MediaItem(
      id: uri,
      title: track.title,
      artist: track.artist.isEmpty
          ? (track.era.isNotEmpty ? track.era : "Ye Tracker")
          : track.artist,
      artUri: artUrl.isNotEmpty ? Uri.tryParse(artUrl) : null,
      extras: null,
    );
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}