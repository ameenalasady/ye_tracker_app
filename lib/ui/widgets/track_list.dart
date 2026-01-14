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
                Icon(Icons.graphic_eq, size: 64, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 16),
                Text(
                  "No tracks found",
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16)
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: tracks.length,
          cacheExtent: 1000,
          padding: const EdgeInsets.only(top: 8, bottom: 120), // Bottom padding for MiniPlayer
          itemBuilder: (context, index) => TrackTile(track: tracks[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF5252))),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Error: $err", style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}