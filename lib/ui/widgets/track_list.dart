import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import 'track_tile.dart';

class TrackList extends ConsumerWidget {
  const TrackList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredTracks = ref.watch(filteredTracksProvider);

    return filteredTracks.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text("No tracks found", style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          );
        }

        // ListView.builder is efficient.
        // cacheExtent keeps items in memory slightly offscreen for smoother scrolling.
        return ListView.separated(
          itemCount: tracks.length,
          cacheExtent: 1000,
          padding: const EdgeInsets.only(bottom: 100), // Space for MiniPlayer
          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
          itemBuilder: (context, index) => TrackTile(track: tracks[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Error: $err"),
        ),
      ),
    );
  }
}