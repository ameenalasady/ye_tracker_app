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
      playbackState.add(playbackState.value.copyWith(
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
        shuffleMode: _player.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: const {
          LoopMode.off: AudioServiceRepeatMode.none,
          LoopMode.one: AudioServiceRepeatMode.one,
          LoopMode.all: AudioServiceRepeatMode.all,
        }[_player.loopMode]!,
      ));
    });
  }

  void _listenToPlaybackState() {
    _player.currentIndexStream.listen((index) {
      if (index != null && _playlist != null && index < _playlist!.length) {
        final source = _playlist!.children[index] as UriAudioSource;
        final item = source.tag as MediaItem;

        mediaItem.add(item);

        // Auto Download Logic delegated to DownloadManager
        final track = item.extras?['track_obj'] as Track?;
        if (track != null) {
          final autoDownload = Hive.box('settings').get('auto_download', defaultValue: true);
          if (autoDownload) {
             // We don't need a callback here, just fire and forget
             downloadManager.downloadTrack(track);
          }
        }
      }
    });

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
    });
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
        final rawIndex = _playlist!.children.indexWhere((s) => (s as UriAudioSource).tag == targetItem);
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

    playbackState.add(playbackState.value.copyWith(
      shuffleMode: shuffleMode,
      updatePosition: _player.position,
    ));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = {
      AudioServiceRepeatMode.none: LoopMode.off,
      AudioServiceRepeatMode.one: LoopMode.one,
      AudioServiceRepeatMode.all: LoopMode.all,
    }[repeatMode]!;
    await _player.setLoopMode(loopMode);

    playbackState.add(playbackState.value.copyWith(
      repeatMode: repeatMode,
      updatePosition: _player.position,
    ));
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final audioSource = _createAudioSource(mediaItem);
    await _playlist?.add(audioSource);
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (_playlist != null && index < queue.value.length) {
      final targetItem = queue.value[index];
      final rawIndex = _playlist!.children.indexWhere((s) => (s as UriAudioSource).tag == targetItem);
      if (rawIndex != -1) {
        await _playlist!.removeAt(rawIndex);
      }
    }
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    if (!_player.shuffleModeEnabled) {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      await _playlist?.move(oldIndex, newIndex);
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
      await _player.setAudioSource(
        _playlist!,
        initialIndex: initialIndex,
      );
      play();
    } catch (e) {
      debugPrint("Error playing playlist: $e");
    }
  }

  Future<void> playTrack(Track track) async {
    await playPlaylist([track], 0);
  }

  AudioSource _createAudioSource(MediaItem item) {
    final track = item.extras?['track_obj'] as Track?;
    if (track == null) {
      return AudioSource.uri(Uri.parse(item.id), tag: item);
    }

    String uri = track.effectiveUrl;
    bool isLocal = track.localPath.isNotEmpty && File(track.localPath).existsSync();

    if (isLocal) {
      uri = track.localPath;
    }

    return AudioSource.uri(
      isLocal ? Uri.file(uri) : Uri.parse(uri),
      tag: item
    );
  }

  MediaItem _createMediaItem(Track track) {
    String uri = track.effectiveUrl;
    if (track.localPath.isNotEmpty && File(track.localPath).existsSync()) {
      uri = track.localPath;
    }

    return MediaItem(
      id: uri,
      title: track.title,
      artist: track.artist.isEmpty ? track.era : track.artist,
      artUri: track.albumArtUrl.isNotEmpty ? Uri.parse(track.albumArtUrl) : null,
      extras: {'track_obj': track},
    );
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}