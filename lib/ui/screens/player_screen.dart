import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/track.dart';
import '../../providers/app_providers.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  double? _dragValue;

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${duration.inMinutes}:$twoDigitSeconds';
  }

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const QueueSheet(),
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
                    'No playlists created yet. Go to Library to create one.',
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
                      // STYLED SNACKBAR
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

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final playbackStateAsync = ref.watch(playbackStateProvider);
    final shuffleModeAsync = ref.watch(shuffleModeProvider);
    final repeatModeAsync = ref.watch(repeatModeProvider);

    final mediaItem = mediaItemAsync.value;
    final playbackState = playbackStateAsync.value;
    final playing = playbackState?.playing ?? false;
    final shuffleMode = shuffleModeAsync.value ?? AudioServiceShuffleMode.none;
    final repeatMode = repeatModeAsync.value ?? AudioServiceRepeatMode.none;

    if (mediaItem == null) return const SizedBox.shrink();

    final currentTrack = mediaItem.extras?['track_obj'] as Track?;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF2A2A2A),
              const Color(0xFF121212).withValues(alpha: 0.9),
            ],
          ),
          image: (mediaItem.artUri != null)
              ? DecorationImage(
                  image: CachedNetworkImageProvider(
                    mediaItem.artUri.toString(),
                    headers: Track.imageHeaders,
                  ),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.8),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- HEADER ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Now Playing',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.playlist_add_rounded,
                        color: Colors.white,
                      ),
                      onPressed: currentTrack != null
                          ? () => _showAddToPlaylistSheet(context, currentTrack)
                          : null,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // --- ARTWORK ---
              Hero(
                tag: 'album_art',
                child: Container(
                  height: MediaQuery.of(context).size.width * 0.85,
                  width: MediaQuery.of(context).size.width * 0.85,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: (mediaItem.artUri != null)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: CachedNetworkImage(
                            imageUrl: mediaItem.artUri.toString(),
                            httpHeaders: Track.imageHeaders,
                            fit: BoxFit.cover,
                            errorWidget: (ctx, _, _) => const Center(
                              child: Icon(
                                Icons.music_note_rounded,
                                size: 120,
                                color: Colors.white12,
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 120,
                            color: Colors.white12,
                          ),
                        ),
                ),
              ),

              const Spacer(),

              // --- TITLE & ARTIST ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Text(
                      mediaItem.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mediaItem.artist ?? 'Unknown Artist',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // --- PROGRESS BAR ---
              StreamBuilder<Duration>(
                stream: AudioService.position,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = mediaItem.duration ?? Duration.zero;

                  var sliderValue =
                      _dragValue ?? position.inMilliseconds.toDouble();
                  var max = duration.inMilliseconds.toDouble();

                  if (max <= 0) max = 1.0;
                  if (sliderValue > max) sliderValue = max;
                  if (sliderValue < 0) sliderValue = 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFFF5252),
                            inactiveTrackColor: Colors.white12,
                            thumbColor: Colors.white,
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                          ),
                          child: Slider(
                            min: 0,
                            max: max,
                            value: sliderValue,
                            onChangeStart: (value) =>
                                setState(() => _dragValue = value),
                            onChanged: (value) =>
                                setState(() => _dragValue = value),
                            onChangeEnd: (value) {
                              audioHandler.seek(
                                Duration(milliseconds: value.toInt()),
                              );
                              setState(() => _dragValue = null);
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(
                                  Duration(milliseconds: sliderValue.toInt()),
                                ),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              // --- CONTROLS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // SHUFFLE BUTTON
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: shuffleMode == AudioServiceShuffleMode.all
                          ? const Color(0xFFFF5252)
                          : Colors.white54,
                    ),
                    onPressed: () {
                      final newMode = shuffleMode == AudioServiceShuffleMode.all
                          ? AudioServiceShuffleMode.none
                          : AudioServiceShuffleMode.all;
                      audioHandler.setShuffleMode(newMode);
                    },
                  ),
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(
                      Icons.skip_previous_rounded,
                      color: Colors.white,
                    ),
                    onPressed: audioHandler.skipToPrevious,
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF7E5F), Color(0xFFFF5252)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x66FF5252),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: IconButton(
                      iconSize: 32,
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.black87,
                      ),
                      onPressed: () =>
                          playing ? audioHandler.pause() : audioHandler.play(),
                    ),
                  ),
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                    ),
                    onPressed: audioHandler.skipToNext,
                  ),
                  // LOOP BUTTON
                  IconButton(
                    icon: Icon(
                      repeatMode == AudioServiceRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: repeatMode == AudioServiceRepeatMode.none
                          ? Colors.white54
                          : const Color(0xFFFF5252),
                    ),
                    onPressed: () {
                      final nextMode = switch (repeatMode) {
                        AudioServiceRepeatMode.none =>
                          AudioServiceRepeatMode.all,
                        AudioServiceRepeatMode.all =>
                          AudioServiceRepeatMode.one,
                        AudioServiceRepeatMode.one =>
                          AudioServiceRepeatMode.none,
                        _ => AudioServiceRepeatMode.none,
                      };
                      audioHandler.setRepeatMode(nextMode);
                    },
                  ),
                ],
              ),

              const Spacer(),

              // --- QUEUE BUTTON ---
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TextButton.icon(
                  onPressed: () => _showQueueSheet(context),
                  icon: const Icon(
                    Icons.queue_music_rounded,
                    color: Colors.white54,
                  ),
                  label: const Text(
                    'Up Next',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- QUEUE SHEET COMPONENT ---
class QueueSheet extends ConsumerStatefulWidget {
  const QueueSheet({super.key});

  @override
  ConsumerState<QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends ConsumerState<QueueSheet> {
  // Track if we have performed the initial scroll to the current song
  bool _initialScrollPerformed = false;

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(queueProvider);
    final currentItemAsync = ref.watch(currentMediaItemProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Up Next',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: queueAsync.when(
                data: (queue) {
                  if (queue.isEmpty) {
                    return const Center(
                      child: Text(
                        'Queue is empty',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  final currentId = currentItemAsync.value?.id;
                  var currentIndex = -1;

                  // Find index of current song
                  if (currentId != null) {
                    currentIndex = queue.indexWhere(
                      (item) => item.id == currentId,
                    );
                  }
                  if (currentIndex == -1 && queue.isNotEmpty) {
                    currentIndex = 0;
                  }

                  // --- WINDOWING LOGIC ---
                  // Load 10 before and 10 after
                  const startOffset = 10;
                  const endOffset =
                      11; // +1 to include the item itself in the range calculation logic

                  // Calculate bounds safely
                  final startIndex = (currentIndex - startOffset).clamp(
                    0,
                    queue.length,
                  );
                  final endIndex = (currentIndex + endOffset).clamp(
                    0,
                    queue.length,
                  );

                  // Create the subset list
                  final visibleQueue = queue.sublist(startIndex, endIndex);

                  // --- SCROLL TO CURRENT SONG LOGIC ---
                  if (!_initialScrollPerformed && visibleQueue.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (scrollController.hasClients) {
                        // Calculate where the current song is relative to the *visible* list
                        final relativeIndex = currentIndex - startIndex;
                        if (relativeIndex > 0) {
                          // 72 is the height of the SizedBox/ListTile below
                          final offset = relativeIndex * 72.0;
                          scrollController.jumpTo(offset);
                        }
                        _initialScrollPerformed = true;
                      }
                    });
                  }

                  return ReorderableListView.builder(
                    scrollController: scrollController,
                    itemCount: visibleQueue.length,
                    proxyDecorator: (child, index, animation) => Material(
                      color: const Color(0xFF2A2A2A),
                      elevation: 6,
                      child: child,
                    ),
                    onReorder: (int oldIndex, int newIndex) {
                      // Map local subset indices back to global indices
                      final globalOldIndex = startIndex + oldIndex;
                      final globalNewIndex = startIndex + newIndex;

                      ref
                          .read(audioHandlerProvider)
                          .moveQueueItem(globalOldIndex, globalNewIndex);
                    },
                    itemBuilder: (context, index) {
                      final item = visibleQueue[index];
                      final isPlaying = item.id == currentId;
                      // Determine the global index for removal logic
                      final globalIndex = startIndex + index;

                      return Dismissible(
                        key: Key('${item.id}_$globalIndex'),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          audioHandler.removeQueueItemAt(globalIndex);
                        },
                        child: SizedBox(
                          height: 72,
                          child: ListTile(
                            key: ValueKey('${item.id}_$globalIndex'),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isPlaying
                                    ? const Color(
                                        0xFFFF5252,
                                      ).withValues(alpha: 0.2)
                                    : const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: isPlaying
                                  ? const Icon(
                                      Icons.graphic_eq,
                                      color: Color(0xFFFF5252),
                                    )
                                  : const Icon(
                                      Icons.music_note,
                                      color: Colors.white24,
                                    ),
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isPlaying
                                    ? const Color(0xFFFF5252)
                                    : Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              item.artist ?? '',
                              maxLines: 1,
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(
                                Icons.drag_handle_rounded,
                                color: Colors.white24,
                              ),
                            ),
                            onTap: () {
                              audioHandler.skipToQueueItem(globalIndex);
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const SizedBox(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
