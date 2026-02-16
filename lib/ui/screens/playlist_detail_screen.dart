import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/playlist.dart';
import '../../providers/app_providers.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_tile.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({required this.playlist, super.key});
  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch playlists to update UI when tracks are removed
    final playlists = ref.watch(playlistsProvider);
    // Find updated instance of this playlist
    final updatedPlaylist = playlists.firstWhere(
      (p) => p.isInBox && p.key == playlist.key,
      orElse: () => playlist,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          updatedPlaylist.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (updatedPlaylist.tracks.isEmpty)
            const Center(
              child: Text(
                'No tracks in this playlist.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: updatedPlaylist.tracks.length,
              itemBuilder: (context, index) {
                final track = updatedPlaylist.tracks[index];
                return Dismissible(
                  key: Key('${track.effectiveUrl}_$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    ref
                        .read(playlistsProvider.notifier)
                        .removeTrackFromPlaylist(updatedPlaylist, track);
                  },
                  child: TrackTile(
                    track: track,
                    // Override tap to play the playlist queue starting from this track
                    onTapOverride: () {
                      ref
                          .read(audioHandlerProvider)
                          .playPlaylist(updatedPlaylist.tracks, index);
                    },
                  ),
                );
              },
            ),
          const Align(alignment: Alignment.bottomCenter, child: MiniPlayer()),
        ],
      ),
    );
  }
}
