import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) stop();
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
        systemActions: const {MediaAction.seek},
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

  Future<void> playTrack(Track track) async {
    String uri = track.link;
    bool isLocal =
        track.localPath.isNotEmpty && File(track.localPath).existsSync();

    if (isLocal) {
      uri = track.localPath;
    } else {
      if (uri.contains('pillows.su/f/')) {
        try {
          final cleanUri = Uri.parse(uri).replace(query: '').toString();
          final id = cleanUri.split('/f/').last.replaceAll('/', '');
          uri = 'https://api.pillows.su/api/download/$id.mp3';
        } catch (e) {
          debugPrint("Error parsing pillow link: $e");
        }
      }
    }

    final item = MediaItem(
      id: uri,
      title: track.title,
      artist: track.artist.isEmpty ? track.era : track.artist,
      duration: null, // Just Audio will determine this
    );

    mediaItem.add(item);

    try {
      if (isLocal) {
        await _player.setFilePath(uri);
      } else {
        // Use LockCachingAudioSource in future for better caching,
        // currently standard setUrl is safest for basic streaming.
        await _player.setUrl(uri);
      }
      play();
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  // Clean up resources when app terminates (if applicable)
  Future<void> dispose() async {
    await _player.dispose();
  }
}