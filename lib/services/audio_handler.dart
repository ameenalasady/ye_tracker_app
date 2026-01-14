import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart'; // Import Hive to check settings directly
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _dio = Dio();

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
    String uri = track.effectiveUrl;
    bool isLocal = track.localPath.isNotEmpty && File(track.localPath).existsSync();

    if (isLocal) {
      debugPrint("Playing from local cache: ${track.localPath}");
      uri = track.localPath;
    } else {
      debugPrint("Streaming: $uri");

      // Check Settings for Auto-Download
      final autoDownload = Hive.box('settings').get('auto_download', defaultValue: true);

      if (autoDownload) {
        _cacheTrack(track);
      }
    }

    final item = MediaItem(
      id: uri,
      title: track.title,
      artist: track.artist.isEmpty ? track.era : track.artist,
      duration: null,
    );

    mediaItem.add(item);

    try {
      if (isLocal) {
        await _player.setFilePath(uri);
      } else {
        await _player.setUrl(uri);
      }
      play();
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  Future<void> _cacheTrack(Track track) async {
    if (track.localPath.isNotEmpty && File(track.localPath).existsSync()) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = track.displayName.replaceAll(RegExp(r'[^\w\s\.-]'), '').trim();
      final savePath = '${dir.path}/$safeName.mp3';

      debugPrint("Starting background cache for: ${track.title}");

      await _dio.download(
        track.effectiveUrl,
        savePath,
        options: Options(receiveTimeout: const Duration(minutes: 10)),
      );

      if (File(savePath).existsSync()) {
        debugPrint("Cache complete: $savePath");
        track.localPath = savePath;
        if (track.isInBox) {
          await track.save();
        }
      }
    } catch (e) {
      debugPrint("Background cache failed for ${track.title}: $e");
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}