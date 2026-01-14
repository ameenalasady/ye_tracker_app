import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  bool _manualDownloading = false;
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

  Future<void> _manualDownload(Track track) async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted == false) {}
    }

    if (!mounted) return;
    setState(() => _manualDownloading = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = track.displayName.replaceAll(RegExp(r'[^\w\s\.-]'), '').trim();
      final savePath = '${dir.path}/$safeName.mp3';

      await Dio().download(
        track.effectiveUrl,
        savePath,
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );

      track.localPath = savePath;
      if (track.isInBox) {
        await track.save();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Download Failed")));
      }
    } finally {
      if (mounted) setState(() => _manualDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.track.isInBox) {
      return ValueListenableBuilder(
        valueListenable: (widget.track.box as Box).listenable(keys: [widget.track.key]),
        builder: (context, box, _) {
          return _buildTileContent(context);
        },
      );
    } else {
      return _buildTileContent(context);
    }
  }

  Widget _buildTileContent(BuildContext context) {
    final t = widget.track;
    final hasLink = t.link.isNotEmpty && t.link != "Link Needed";
    final isDownloaded = t.localPath.isNotEmpty && File(t.localPath).existsSync();

    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final playbackStateAsync = ref.watch(playbackStateProvider);

    final activeDownloads = ref.watch(activeDownloadsProvider).value ?? {};
    final isAutoDownloading = activeDownloads.contains(t.effectiveUrl);

    final isProcessingDownload = _manualDownloading || isAutoDownloading;

    final currentMediaId = mediaItemAsync.value?.id;
    final isCurrentTrack = currentMediaId == t.effectiveUrl || (t.localPath.isNotEmpty && currentMediaId == t.localPath);

    final playbackState = playbackStateAsync.value;
    final isPlaying = isCurrentTrack && (playbackState?.playing ?? false);
    final isBuffering = isCurrentTrack && (playbackState?.processingState == AudioProcessingState.buffering || playbackState?.processingState == AudioProcessingState.loading);

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
            ? Border.all(color: activeBorderColor.withAlpha((0.8 * 255).toInt()), width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
          boxShadow: isCurrentTrack
            ? [BoxShadow(color: activeBorderColor.withAlpha((0.25 * 255).toInt()), blurRadius: 12, spreadRadius: 0)]
            : [const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            // --- ARTWORK OR ICON ---
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isCurrentTrack ? activeBorderColor.withAlpha((0.15 * 255).toInt()) : Colors.white.withAlpha((0.05 * 255).toInt()),
                    borderRadius: BorderRadius.circular(12),
                    image: t.albumArtUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(t.albumArtUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: t.albumArtUrl.isEmpty
                      ? Center(child: _buildLeadingIcon(isCurrentTrack, isPlaying, isBuffering))
                      : null,
                ),
                // Overlay playing animation on top of image if playing
                if (t.albumArtUrl.isNotEmpty && (isBuffering || (isCurrentTrack && isPlaying)))
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((0.5 * 255).toInt()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: _buildLeadingIcon(isCurrentTrack, isPlaying, isBuffering)),
                  ),
              ],
            ),

            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isCurrentTrack ? activeBorderColor : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      t.artist,
                      if (t.era.isNotEmpty) t.era,
                      if (t.length.isNotEmpty) t.length
                    ].where((s) => s.isNotEmpty).join(" • "),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            _buildTrailingAction(hasLink, isDownloaded, isProcessingDownload),
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
          return SizedBox(
            height: 24,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(0.6), const SizedBox(width: 3),
                _bar(1.0), const SizedBox(width: 3),
                _bar(0.4),
              ],
            ),
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

  Widget _buildTrailingAction(bool hasLink, bool isDownloaded, bool isDownloading) {
    if (isDownloading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)
      );
    }
    if (isDownloaded) {
      return const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 24);
    }
    if (hasLink) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha((0.05 * 255).toInt()),
        ),
        child: IconButton(
          icon: const Icon(Icons.download_rounded, color: Colors.white38, size: 20),
          onPressed: () => _manualDownload(widget.track),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}