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
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600)
    )..repeat(reverse: true);
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download Failed")));
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

    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final playbackStateAsync = ref.watch(playbackStateProvider);

    final currentMediaId = mediaItemAsync.value?.id;
    final isCurrentTrack = currentMediaId == t.link || (t.localPath.isNotEmpty && currentMediaId == t.localPath);

    final playbackState = playbackStateAsync.value;
    final isPlaying = isCurrentTrack && (playbackState?.playing ?? false);
    final isBuffering = isCurrentTrack && (playbackState?.processingState == AudioProcessingState.buffering || playbackState?.processingState == AudioProcessingState.loading);

    // --- UI CONFIGURATION ---
    final Color cardColor = const Color(0xFF252525);
    final Color activeBorderColor = const Color(0xFFFF5252);

    return GestureDetector(
      onTap: () {
        if (hasLink || isDownloaded) {
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isCurrentTrack
            ? Border.all(color: activeBorderColor.withOpacity(0.8), width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
          boxShadow: isCurrentTrack
            ? [BoxShadow(color: activeBorderColor.withOpacity(0.25), blurRadius: 12, spreadRadius: 0)]
            : [const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Leading Icon Box
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isCurrentTrack ? activeBorderColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _buildLeadingIcon(isCurrentTrack, isPlaying, isBuffering),
              ),
            ),
            const SizedBox(width: 16),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isCurrentTrack ? activeBorderColor : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if(t.era.isNotEmpty) ...[
                        Text(t.era, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        Text(" • ", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                      Text(t.length, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),

            // Action Icons
            _buildTrailingAction(hasLink, isDownloaded),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(bool isCurrent, bool isPlaying, bool isBuffering) {
    if (isBuffering) {
      return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5252)));
    }
    if (isCurrent && isPlaying) {
      return AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(0.6), const SizedBox(width: 3),
              _bar(1.0), const SizedBox(width: 3),
              _bar(0.4),
            ],
          );
        },
      );
    }
    return Icon(
      isCurrent ? Icons.pause_rounded : Icons.music_note_rounded,
      color: isCurrent ? const Color(0xFFFF5252) : Colors.white24,
      size: 24,
    );
  }

  Widget _bar(double scaleMultiplier) {
    final height = 8.0 + (10.0 * _animController.value * scaleMultiplier) + (Random().nextDouble() * 4);
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
      return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24));
    }
    if (isDownloaded) {
      return const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 24);
    }
    if (hasLink && widget.track.link.contains('pillows.su')) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
        ),
        child: IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.white38, size: 20),
          onPressed: () => _download(widget.track),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}