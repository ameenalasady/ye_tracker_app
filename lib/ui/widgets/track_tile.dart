import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
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

class _TrackTileState extends ConsumerState<TrackTile> {
  bool _downloading = false;

  Future<void> _download(Track track) async {
    if (Platform.isAndroid) {
       // Android 13+ (SDK 33) doesn't need external storage permission for app docs
       if (await Permission.storage.request().isGranted == false) {
         // Proceeding anyway as getApplicationDocumentsDirectory usually doesn't need explicit perm
       }
    }

    if (!mounted) return;
    setState(() => _downloading = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      // Sanitize filename to prevent file system errors
      final safeName = track.displayName.replaceAll(RegExp(r'[^\w\s\.-]'), '').trim();
      final savePath = '${dir.path}/$safeName.mp3';

      String downloadUrl = track.link;
      // Handle Pillows API conversion
      if (track.link.contains('pillows.su/f/')) {
         final cleanUri = Uri.parse(track.link).replace(query: '').toString();
         final id = cleanUri.split('/f/').last.replaceAll('/', '');
         downloadUrl = 'https://api.pillows.su/api/download/$id.mp3';
      }

      // Download with timeout
      await Dio().download(
        downloadUrl,
        savePath,
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );

      // Update Hive Object
      final newTrack = track.copyWith(localPath: savePath);
      final boxName = 'tracks_${ref.read(selectedTabProvider)!.gid}';

      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<Track>(boxName).put(track.key, newTrack);
        // Force refresh of track list to show checkmark (optional, Hive usually reactive)
        ref.invalidate(tracksProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Download Complete"), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download Failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final hasLink = t.link.isNotEmpty && t.link != "Link Needed";
    final isDownloaded = t.localPath.isNotEmpty && File(t.localPath).existsSync();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        t.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            "${t.era} • ${t.length}",
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          if (t.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                t.notes,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDownloaded)
            const Icon(Icons.check_circle, color: Colors.green, size: 20)
          else if (_downloading)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else if (hasLink && t.link.contains('pillows.su'))
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white70),
              onPressed: () => _download(t),
            ),
        ],
      ),
      onTap: () {
        if (hasLink || isDownloaded) {
          ref.read(audioHandlerProvider).playTrack(t);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No valid link found.")),
          );
        }
      },
    );
  }
}