import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart'; // IMPORT THIS
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
  // Used to decouple the slider from the player while dragging
  double? _dragValue;

  String _formatDuration(Duration? duration) {
    if (duration == null) return "--:--";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inMinutes}:$twoDigitSeconds";
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
          // Background blur image
          image: (mediaItem.artUri != null)
              ? DecorationImage(
                  // CHANGED: CachedNetworkImageProvider
                  image: CachedNetworkImageProvider(
                    mediaItem.artUri.toString(),
                    headers: Track.imageHeaders, // Fixes 403
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
              // --- HEADER (Dismiss Button) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    const Text(
                      "Now Playing",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // Balance the row
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
                          // CHANGED: CachedNetworkImage
                          child: CachedNetworkImage(
                            imageUrl: mediaItem.artUri.toString(),
                            httpHeaders: Track.imageHeaders, // Fixes 403
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

                  // Use _dragValue while dragging, otherwise use actual position
                  double sliderValue = (_dragValue ?? position.inMilliseconds.toDouble());
                  double max = duration.inMilliseconds.toDouble();

                  // Safety checks
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
                            // Called when user touches the slider
                            onChangeStart: (value) {
                               setState(() {
                                 _dragValue = value;
                               });
                            },
                            // Called while dragging
                            onChanged: (value) {
                              setState(() {
                                _dragValue = value;
                              });
                            },
                            // Called when user releases
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