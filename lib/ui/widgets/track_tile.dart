import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/track.dart';
import '../../providers/app_providers.dart';

class TrackTile extends ConsumerStatefulWidget {
  const TrackTile({required this.track, this.onTapOverride, super.key});
  final Track track;
  final VoidCallback? onTapOverride;

  @override
  ConsumerState<TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends ConsumerState<TrackTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _manualDownload(Track track) {
    final manager = ref.read(downloadManagerProvider);
    manager.downloadTrack(
      track,
      onError: (msg) {
        if (mounted) {
          _showToast(context, msg, isError: true);
        }
      },
      onSuccess: () {
        // Optional: Show success msg
      },
    );
  }

  void _showToast(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline,
              color: isError ? const Color(0xFFFF5252) : Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final playlists = ref.watch(playlistsProvider);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add to Playlist',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No playlists created yet.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                ...playlists.map(
                  (playlist) => ListTile(
                    leading: const Icon(
                      Icons.playlist_add,
                      color: Colors.white54,
                    ),
                    title: Text(
                      playlist.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      ref
                          .read(playlistsProvider.notifier)
                          .addTrackToPlaylist(playlist, track);
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.playlist_add_check_rounded,
                                color: Color(0xFFFF5252),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Added to ${playlist.name}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.track.isInBox) {
      return ValueListenableBuilder(
        valueListenable: (widget.track.box! as Box).listenable(
          keys: [widget.track.key],
        ),
        builder: (context, box, _) => _buildWithGlobalListener(context),
      );
    } else {
      return _buildWithGlobalListener(context);
    }
  }

  Widget _buildWithGlobalListener(BuildContext context) {
    final downloadsBox = Hive.box('downloads');
    return ValueListenableBuilder(
      valueListenable: downloadsBox.listenable(
        keys: [widget.track.effectiveUrl],
      ),
      builder: (context, Box box, _) {
        final globalPath = box.get(widget.track.effectiveUrl);
        return _buildTileContent(context, globalPath);
      },
    );
  }

  Widget _buildTileContent(BuildContext context, String? globalPath) {
    final t = widget.track;
    final hasLink = t.link.isNotEmpty && t.link != 'Link Needed';

    final isDownloaded =
        (t.localPath.isNotEmpty && File(t.localPath).existsSync()) ||
        (globalPath != null && File(globalPath).existsSync());

    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final playbackStateAsync = ref.watch(playbackStateProvider);

    final activeDownloads = ref.watch(activeDownloadsProvider).value ?? {};
    final isDownloading = activeDownloads.contains(t.effectiveUrl);

    final mediaItem = mediaItemAsync.value;
    var isCurrentTrack = false;

    if (mediaItem != null) {
      final currentTrackObj = mediaItem.extras?['track_obj'] as Track?;
      if (currentTrackObj != null) {
        isCurrentTrack = currentTrackObj == t;
      } else {
        isCurrentTrack =
            mediaItem.id == t.effectiveUrl ||
            (isDownloaded && mediaItem.id == (globalPath ?? t.localPath));
      }
    }

    final playbackState = playbackStateAsync.value;
    final processingState = playbackState?.processingState;

    final isPlaying =
        isCurrentTrack &&
        (playbackState?.playing ?? false) &&
        processingState != AudioProcessingState.completed;

    final isBuffering =
        isCurrentTrack &&
        (processingState == AudioProcessingState.buffering ||
            processingState == AudioProcessingState.loading);

    if (isPlaying && !_animController.isAnimating) {
      _animController.repeat();
    } else if (!isPlaying && _animController.isAnimating) {
      _animController.stop();
      _animController.reset();
    }

    const cardColor = Color(0xFF252525);
    const activeBorderColor = Color(0xFFFF5252);

    // This getter checks the global hive box if the local url is empty
    final artUrl = t.effectiveAlbumArt;

    return GestureDetector(
      onLongPress: () => _showAddToPlaylistSheet(context, t),
      onTap: () async {
        if (isDownloaded) {
          if (t.localPath.isEmpty && globalPath != null) {
            t.localPath = globalPath;
          }
          _playTrack(t, isCurrentTrack, isPlaying);
        } else if (hasLink) {
          final online = await _hasInternet();
          if (!online) {
            if (context.mounted) {
              _showToast(
                context,
                'No Internet. Download tracks to play offline.',
                isError: true,
              );
            }
          } else {
            _playTrack(t, isCurrentTrack, isPlaying);
          }
        } else {
          _showToast(context, 'No valid link found.', isError: true);
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
              ? Border.all(
                  color: activeBorderColor.withAlpha((0.8 * 255).toInt()),
                  width: 1.5,
                )
              : Border.all(color: Colors.transparent, width: 1.5),
          boxShadow: isCurrentTrack
              ? [
                  BoxShadow(
                    color: activeBorderColor.withAlpha((0.25 * 255).toInt()),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // --- ARTWORK ---
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isCurrentTrack
                        ? activeBorderColor.withAlpha((0.15 * 255).toInt())
                        : Colors.white.withAlpha((0.05 * 255).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: artUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: artUrl,
                            // Ensure headers are passed for authentication/hotlink protection
                            httpHeaders: Track.imageHeaders,
                            fit: BoxFit.cover,
                            memCacheHeight: 150, // Memory optimization
                            fadeInDuration: const Duration(milliseconds: 200),
                            placeholder: (context, url) => Center(
                              child: _buildLeadingIcon(
                                isCurrentTrack,
                                isPlaying,
                                isBuffering,
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: _buildLeadingIcon(
                                isCurrentTrack,
                                isPlaying,
                                isBuffering,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: _buildLeadingIcon(
                            isCurrentTrack,
                            isPlaying,
                            isBuffering,
                          ),
                        ),
                ),
                if (artUrl.isNotEmpty &&
                    (isBuffering || (isCurrentTrack && isPlaying)))
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((0.5 * 255).toInt()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _buildLeadingIcon(
                        isCurrentTrack,
                        isPlaying,
                        isBuffering,
                      ),
                    ),
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
                      if (t.length.isNotEmpty) t.length,
                    ].where((s) => s.isNotEmpty).join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            _buildTrailingAction(hasLink, isDownloaded, isDownloading),
          ],
        ),
      ),
    );
  }

  void _playTrack(Track t, bool isCurrentTrack, bool isPlaying) {
    if (widget.onTapOverride != null) {
      widget.onTapOverride!();
      return;
    }

    final handler = ref.read(audioHandlerProvider);
    if (isCurrentTrack) {
      isPlaying ? handler.pause() : handler.play();
    } else {
      final currentContextList = ref.read(filteredTracksProvider).value ?? [];

      if (currentContextList.isEmpty) {
        handler.playTrack(t);
      } else {
        final index = currentContextList.indexOf(t);
        if (index != -1) {
          handler.playPlaylist(currentContextList, index);
        } else {
          handler.playTrack(t);
        }
      }
    }
  }

  Widget _buildLeadingIcon(bool isCurrent, bool isPlaying, bool isBuffering) {
    if (isBuffering) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFFF5252),
        ),
      );
    }
    if (isCurrent && isPlaying) {
      return AnimatedBuilder(
        animation: _animController,
        builder: (context, child) => SizedBox(
          height: 24,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBar(0),
              const SizedBox(width: 3),
              _buildBar(1),
              const SizedBox(width: 3),
              _buildBar(2),
            ],
          ),
        ),
      );
    }
    return Icon(
      isCurrent ? Icons.pause_rounded : Icons.music_note_rounded,
      color: isCurrent ? const Color(0xFFFF5252) : Colors.white24,
      size: 24,
    );
  }

  Widget _buildBar(int index) {
    final t = _animController.value;
    final offset = index * (pi / 2);
    final wave = 0.5 * (sin(t * 2 * pi + offset) + 1);
    final height = 6.0 + (wave * 12.0);

    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFF5252),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTrailingAction(
    bool hasLink,
    bool isDownloaded,
    bool isDownloading,
  ) {
    const boxSize = 40.0;

    if (isDownloading) {
      return const SizedBox(
        width: boxSize,
        height: boxSize,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white24,
            ),
          ),
        ),
      );
    }

    if (isDownloaded) {
      return const SizedBox(
        width: boxSize,
        height: boxSize,
        child: Center(
          child: Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF4CAF50),
            size: 24,
          ),
        ),
      );
    }

    if (hasLink) {
      return Container(
        width: boxSize,
        height: boxSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha((0.05 * 255).toInt()),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(
            Icons.download_rounded,
            color: Colors.white38,
            size: 20,
          ),
          onPressed: () => _manualDownload(widget.track),
        ),
      );
    }

    return const SizedBox(width: boxSize, height: boxSize);
  }
}
