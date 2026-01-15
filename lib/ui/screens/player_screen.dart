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
    if (duration == null) return "--:--";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inMinutes}:$twoDigitSeconds";
  }

  void _showAddToPlaylistSheet(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final playlists = ref.watch(playlistsProvider);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Add to Playlist", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No playlists created yet. Go to Library to create one.", style: TextStyle(color: Colors.white54)),
                )
              else
                ...playlists.map((playlist) => ListTile(
                  leading: const Icon(Icons.playlist_add, color: Colors.white54),
                  title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    ref.read(playlistsProvider.notifier).addTrackToPlaylist(playlist, track);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Added to ${playlist.name}")),
                    );
                  },
                )),
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

    final mediaItem = mediaItemAsync.value;
    final playbackState = playbackStateAsync.value;
    final playing = playbackState?.playing ?? false;

    if (mediaItem == null) return const SizedBox.shrink();

    // Retrieve the Track object from extras if available
    final Track? currentTrack = mediaItem.extras?['track_obj'] as Track?;

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
                    BlendMode.darken
                  ),
                )
              : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- HEADER ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "Now Playing",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // NEW: Add to Playlist Button
                    IconButton(
                      icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
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
                            errorWidget: (ctx, _, __) => const Center(
                              child: Icon(Icons.music_note_rounded, size: 120, color: Colors.white12),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.music_note_rounded, size: 120, color: Colors.white12),
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
                      mediaItem.artist ?? "Unknown Artist",
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

                  double sliderValue = (_dragValue ?? position.inMilliseconds.toDouble());
                  double max = duration.inMilliseconds.toDouble();

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
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          ),
                          child: Slider(
                            min: 0,
                            max: max,
                            value: sliderValue,
                            onChangeStart: (value) {
                               setState(() {
                                 _dragValue = value;
                               });
                            },
                            onChanged: (value) {
                              setState(() {
                                _dragValue = value;
                              });
                            },
                            onChangeEnd: (value) {
                              audioHandler.seek(Duration(milliseconds: value.toInt()));
                              setState(() {
                                _dragValue = null;
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(Duration(milliseconds: sliderValue.toInt())),
                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // --- CONTROLS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                    onPressed: () => audioHandler.skipToPrevious(),
                  ),
                  const SizedBox(width: 32),
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
                        )
                      ],
                    ),
                    child: IconButton(
                      iconSize: 32,
                      icon: Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black87,
                      ),
                      onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
                    ),
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                    onPressed: () => audioHandler.skipToNext(),
                  ),
                ],
              ),

              const Spacer(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}