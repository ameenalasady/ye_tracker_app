import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _dio = Dio();

  final ValueNotifier<Set<String>> downloadingTracks = ValueNotifier({});

  MyAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);

    _player.durationStream.listen((duration) {
      final currentItem = mediaItem.value;
      if (currentItem != null && duration != null) {
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
    });

    // --- FIX: Handle End of Queue Correctly ---
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // If there is a next song, just_audio usually handles it with ConcatenatingAudioSource,
        // but if we are at the end, we MUST manually pause to update the UI state.
        if (_player.hasNext) {
          _player.seekToNext();
        } else {
          // End of playlist or single track: Stop playback and reset to 0
          _player.pause();
          _player.seek(Duration.zero);
        }
      }
    });

    // Sync current media item with queue index
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
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
      ),
    );
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

  // --- Play a list of tracks (Playlist) ---
  Future<void> playPlaylist(List<Track> tracks, int initialIndex) async {
    // 1. Convert Tracks to MediaItems
    final mediaItems = tracks.map((track) => _createMediaItem(track)).toList();

    // 2. Update Queue
    queue.add(mediaItems);

    // Force update the current media item immediately.
    if (mediaItems.isNotEmpty && initialIndex < mediaItems.length) {
      mediaItem.add(mediaItems[initialIndex]);
    }

    // 3. Setup Audio Sources
    final audioSources = tracks.map((track) {
      String uri = track.effectiveUrl;
      bool isLocal = track.localPath.isNotEmpty && File(track.localPath).existsSync();

      if (isLocal) {
        uri = track.localPath;
      } else {
        final autoDownload = Hive.box('settings').get('auto_download', defaultValue: true);
        if (autoDownload) {
          _cacheTrack(track);
        }
      }

      return AudioSource.uri(
        isLocal ? Uri.file(uri) : Uri.parse(uri),
        tag: _createMediaItem(track)
      );
    }).toList();

    // 4. Load into Player
    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: audioSources),
        initialIndex: initialIndex,
      );
      play();
    } catch (e) {
      debugPrint("Error playing playlist: $e");
    }
  }

  // --- Play Single Track ---
  Future<void> playTrack(Track track) async {
    await playPlaylist([track], 0);
  }

  MediaItem _createMediaItem(Track track) {
    String uri = track.effectiveUrl;
    if (track.localPath.isNotEmpty && File(track.localPath).existsSync()) {
      uri = track.localPath;
    }

    return MediaItem(
      id: uri, // Use URI as ID
      title: track.title,
      artist: track.artist.isEmpty ? track.era : track.artist,
      artUri: track.albumArtUrl.isNotEmpty ? Uri.parse(track.albumArtUrl) : null,
      extras: {'track_obj': track}, // Store full object for UI comparison
    );
  }

  Future<void> _cacheTrack(Track track) async {
    if (track.localPath.isNotEmpty && File(track.localPath).existsSync()) return;
    if (downloadingTracks.value.contains(track.effectiveUrl)) return;

    try {
      downloadingTracks.value = {...downloadingTracks.value, track.effectiveUrl};
      final dir = await getApplicationDocumentsDirectory();
      final safeName = track.displayName.replaceAll(RegExp(r'[^\w\s\.-]'), '').trim();
      final savePath = '${dir.path}/$safeName.mp3';

      await _dio.download(
        track.effectiveUrl,
        savePath,
        options: Options(receiveTimeout: const Duration(minutes: 10)),
      );

      if (File(savePath).existsSync()) {
        track.localPath = savePath;
        if (track.isInBox) {
          await track.save();
        }
      }
    } catch (e) {
      debugPrint("Background cache failed for ${track.title}: $e");
    } finally {
      final set = Set<String>.from(downloadingTracks.value);
      set.remove(track.effectiveUrl);
      downloadingTracks.value = set;
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    downloadingTracks.dispose();
  }
}