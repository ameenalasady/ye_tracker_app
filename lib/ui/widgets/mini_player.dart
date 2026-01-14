import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final playbackStateAsync = ref.watch(playbackStateProvider);

    final mediaItem = mediaItemAsync.value;
    if (mediaItem == null) return const SizedBox.shrink();

    final playing = playbackStateAsync.value?.playing ?? false;
    final processingState = playbackStateAsync.value?.processingState;
    final isLoading = processingState == AudioProcessingState.loading || processingState == AudioProcessingState.buffering;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF25090C), // Slightly richer dark red/brown
        border: Border(top: BorderSide(color: Colors.white10)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // PROGRESS BAR
          StreamBuilder<Duration>(
            stream: AudioService.position,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = mediaItem.duration ?? Duration.zero;
              double progress = 0.0;
              if (duration.inMilliseconds > 0) {
                progress = position.inMilliseconds / duration.inMilliseconds;
                if (progress > 1.0) progress = 1.0;
              }
              return LinearProgressIndicator(
                value: isLoading ? null : progress, // Indeterminate if loading
                backgroundColor: Colors.transparent,
                color: const Color(0xFFFF5252),
                minHeight: 2,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                    image: const DecorationImage(
                      image: NetworkImage("https://upload.wikimedia.org/wikipedia/commons/thumb/1/10/Kanye_West_at_the_2009_Tribeca_Film_Festival_%28cropped%29.jpg/440px-Kanye_West_at_the_2009_Tribeca_Film_Festival_%28cropped%29.jpg"), // Placeholder or fetch album art if available
                      fit: BoxFit.cover,
                      opacity: 0.5
                    )
                  ),
                  child: const Center(child: Icon(Icons.music_note, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mediaItem.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        mediaItem.artist ?? "Unknown Artist",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(isLoading
                    ? Icons.circle_outlined // visual placeholder while loading spinner overlay is active
                    : (playing ? Icons.pause_circle_filled : Icons.play_circle_filled)),
                  iconSize: 42,
                  color: Colors.white,
                  onPressed: () {
                    if (playing) audioHandler.pause();
                    else audioHandler.play();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}