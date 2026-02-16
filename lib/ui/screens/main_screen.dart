import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/app_providers.dart';
import '../../services/update_manager.dart';
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpdateAvailableDialog(release: release),
      );
    }
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

// --- PUBLIC DIALOGS (Accessible from Settings) ---

class UpdateAvailableDialog extends StatelessWidget {
  const UpdateAvailableDialog({required this.release, super.key});
  final UpdateRelease release;

  @override
  Widget build(BuildContext context) => AlertDialog(
      backgroundColor: const Color(0xFF252525),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.new_releases_rounded,
              color: Color(0xFFFF5252),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Update Available',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Version ${release.tagName} is now available.',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: SingleChildScrollView(
              child: Text(
                release.body,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF5252),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => UpdateDownloadDialog(release: release),
            );
          },
          child: const Text('Update Now'),
        ),
      ],
    );
}

class UpdateDownloadDialog extends ConsumerStatefulWidget {
  const UpdateDownloadDialog({required this.release, super.key});
  final UpdateRelease release;

  @override
  ConsumerState<UpdateDownloadDialog> createState() =>
      _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends ConsumerState<UpdateDownloadDialog> {
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
                _status = 'Downloading...';
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
            // Close dialog on success (OS installer takes over)
            Navigator.pop(context);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).clamp(0, 100).toInt();

    return AlertDialog(
      backgroundColor: const Color(0xFF252525),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_error) ...[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.cloud_download_rounded,
                  color: Color(0xFFFF5252),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: Colors.white10,
                color: const Color(0xFFFF5252),
              ),
            ),
          ] else ...[
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Update Failed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    launchUrl(
                      Uri.parse(widget.release.htmlUrl),
                      mode: LaunchMode.externalApplication,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Open Browser',
                    style: TextStyle(color: Color(0xFFFF5252)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
