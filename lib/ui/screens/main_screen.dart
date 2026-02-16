import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart'; // Import for fallback

import '../../providers/app_providers.dart';
import '../../services/update_manager.dart'; // Import
import '../sheets/filter_sheet.dart';
import '../sheets/playlists_sheet.dart';
import '../sheets/settings_sheet.dart';
import '../widgets/era_tab_selector.dart';
import '../widgets/main_header.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_list.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    // Schedule update check after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    final updateManager = ref.read(updateManagerProvider);
    final release = await updateManager.checkForUpdates();

    if (release != null && mounted) {
      _showUpdateDialog(release);
    }
  }

  void _showUpdateDialog(UpdateRelease release) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text(
          'New Update Available',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${release.tagName} is available.',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  release.body,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showDownloadProgressDialog(release);
            },
            child: const Text(
              'Update Now',
              style: TextStyle(color: Color(0xFFFF5252)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDownloadProgressDialog(UpdateRelease release) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadDialog(release: release),
    );
  }

  void _showPlaylistsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => const PlaylistsSheet(),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => const FilterSheet(),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 50),
              // --- Component: Header ---
              MainHeader(
                onPlaylistsTap: () => _showPlaylistsSheet(context),
                onFilterTap: () => _showFilterSheet(context),
                onSettingsTap: () => _showSettingsSheet(context),
              ),
              const SizedBox(height: 16),
              // --- Component: Tab Selector ---
              const EraTabSelector(),
              const SizedBox(height: 10),
              // --- Component: Track List ---
              const Expanded(child: TrackList()),
            ],
          ),
          // --- Component: Mini Player ---
          const Align(alignment: Alignment.bottomCenter, child: MiniPlayer()),
        ],
      ),
    );
}

// Internal widget to handle download state
class _DownloadDialog extends ConsumerStatefulWidget {
  const _DownloadDialog({required this.release});
  final UpdateRelease release;

  @override
  ConsumerState<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends ConsumerState<_DownloadDialog> {
  double _progress = 0;
  String _status = 'Starting download...';
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() {
    ref
        .read(updateManagerProvider)
        .downloadAndInstall(
          widget.release,
          onProgress: (p) {
            if (mounted) {
              setState(() {
                _progress = p;
                _status = 'Downloading ${(p * 100).toStringAsFixed(0)}%';
              });
            }
          },
          onError: (msg) {
            if (mounted) {
              setState(() {
                _status = msg;
                _error = true;
              });
            }
          },
        )
        .then((_) {
          if (!_error && mounted) {
            Navigator.pop(
              context,
            ); // Close dialog on success (OS installer takes over)
          }
        });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
      backgroundColor: const Color(0xFF252525),
      title: const Text('Updating...', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _status,
            style: TextStyle(color: _error ? Colors.red : Colors.white70),
          ),
          const SizedBox(height: 16),
          if (!_error)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white10,
              color: const Color(0xFFFF5252),
            ),
        ],
      ),
      actions: [
        if (_error)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        // Fallback to open browser if in-app fails
        if (_error)
          TextButton(
            onPressed: () {
              launchUrl(
                Uri.parse(widget.release.htmlUrl),
                mode: LaunchMode.externalApplication,
              );
              Navigator.pop(context);
            },
            child: const Text(
              'Open in Browser',
              style: TextStyle(color: Color(0xFFFF5252)),
            ),
          ),
      ],
    );
}
