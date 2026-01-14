import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/track.dart';
import '../../providers/app_providers.dart';

class TrackTile extends ConsumerStatefulWidget {
  final Track track;
  const TrackTile({required this.track, super.key});

  @override
  ConsumerState<TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends ConsumerState<TrackTile> with SingleTickerProviderStateMixin {
  bool _downloading = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _download(Track track) async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted == false) {}
    }

    if (!mounted) return;
    setState(() => _downloading = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = track.displayName.replaceAll(RegExp(r'[^\w\s\.-]'), '').trim();
      final savePath = '${dir.path}/$safeName.mp3';

      String downloadUrl = track.link;
      if (track.link.contains('pillows.su/f/')) {
         final cleanUri = Uri.parse(track.link).replace(query: '').toString();
         final id = cleanUri.split('/f/').last.replaceAll('/', '');
         downloadUrl = 'https://api.pillows.su/api/download/$id.mp3';
      }

      await Dio().download(
        downloadUrl,
        savePath,
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );

      final newTrack = track.copyWith(localPath: savePath);
      final boxName = 'tracks_${ref.read(selectedTabProvider)!.gid}';

      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<Track>(boxName).put(track.key, newTrack);
        ref.invalidate(tracksProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download Failed")));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final hasLink = t.link.isNotEmpty && t.link != "Link Needed";
    final isDownloaded = t.localPath.isNotEmpty && File(t.localPath).existsSync();

    // Listen to stream providers
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final playbackStateAsync = ref.watch(playbackStateProvider);

    final currentMediaId = mediaItemAsync.value?.id;
    // Check if this specific track is the one loaded in AudioService
    final isCurrentTrack = currentMediaId == t.link || (t.localPath.isNotEmpty && currentMediaId == t.localPath);

    final playbackState = playbackStateAsync.value;
    final isPlaying = isCurrentTrack && (playbackState?.playing ?? false);
    final isBuffering = isCurrentTrack && (playbackState?.processingState == AudioProcessingState.buffering || playbackState?.processingState == AudioProcessingState.loading);

    return Container(
      color: isCurrentTrack ? const Color(0xFF3E1C1F) : Colors.transparent, // Highlight active track
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        // --- LEADING ICON: Visual State Indicator ---
        leading: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: _buildLeadingIcon(isCurrentTrack, isPlaying, isBuffering),
          ),
        ),
        title: Text(
          t.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.w600,
            color: isCurrentTrack ? const Color(0xFFFF5252) : Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "${t.era} • ${t.length}",
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
        trailing: _buildTrailingAction(hasLink, isDownloaded),
        onTap: () {
          if (hasLink || isDownloaded) {
             // If currently playing, toggle pause
             if (isCurrentTrack) {
               final handler = ref.read(audioHandlerProvider);
               isPlaying ? handler.pause() : handler.play();
             } else {
               ref.read(audioHandlerProvider).playTrack(t);
             }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No valid link found."), duration: Duration(milliseconds: 500)),
            );
          }
        },
      ),
    );
  }

  Widget _buildLeadingIcon(bool isCurrent, bool isPlaying, bool isBuffering) {
    if (isBuffering) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    if (isCurrent && isPlaying) {
      // Custom Animated Equalizer
      return AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(0.6),
              const SizedBox(width: 2),
              _bar(1.0),
              const SizedBox(width: 2),
              _bar(0.4),
            ],
          );
        },
      );
    }
    if (isCurrent && !isPlaying) {
      return const Icon(Icons.pause, color: Colors.white70);
    }
    return const Icon(Icons.music_note_rounded, color: Colors.white12);
  }

  Widget _bar(double scaleMultiplier) {
    // Generate random height based on controller
    final height = 8.0 + (12.0 * _animController.value * scaleMultiplier) + (Random().nextDouble() * 4);
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFF5252),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTrailingAction(bool hasLink, bool isDownloaded) {
    if (_downloading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
      );
    }
    if (isDownloaded) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 20);
    }
    if (hasLink && widget.track.link.contains('pillows.su')) {
      return IconButton(
        icon: const Icon(Icons.download_rounded, color: Colors.white38),
        onPressed: () => _download(widget.track),
      );
    }
    return const SizedBox.shrink();
  }
}