import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2C0B0E),
            border: Border(top: BorderSide(color: Colors.white10)),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, -2))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.music_note, color: Colors.white70),
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
              StreamBuilder<PlaybackState>(
                stream: audioHandler.playbackState,
                builder: (context, stateSnap) {
                  final playing = stateSnap.data?.playing ?? false;
                  final processingState = stateSnap.data?.processingState;

                  if (processingState == AudioProcessingState.loading ||
                      processingState == AudioProcessingState.buffering) {
                     return const SizedBox(
                       width: 48,
                       height: 48,
                       child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                     );
                  }

                  return IconButton(
                    icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    iconSize: 42,
                    color: Colors.white,
                    onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}