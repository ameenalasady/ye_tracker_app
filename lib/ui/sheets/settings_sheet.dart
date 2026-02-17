import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../screens/main_screen.dart'; // Import to access UpdateAvailableDialog

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  late TextEditingController _sourceController;
  bool _isRefreshing = false;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _sourceController = TextEditingController(
      text: ref.read(sourceUrlProvider),
    );
  }

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _refreshLibrary() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    final selectedTab = ref.read(selectedTabProvider);

    try {
      if (selectedTab != null) {
        await ref.read(tracksRepositoryProvider).clearLocalCache(selectedTab);
        ref.invalidate(tracksProvider);
      } else {
        ref.invalidate(tabsProvider);
      }
      ref.invalidate(cacheSizeProvider);

      if (mounted) {
        // FIX: Close the sheet first so the SnackBar is visible on the MainScreen
        Navigator.pop(context);

        _showToast(
          context,
          'Library refreshed successfully',
          icon: Icons.check_circle_rounded,
          iconColor: Colors.greenAccent,
        );
      }
    } catch (e) {
      if (mounted) {
        // Even on error, close sheet to show the error message clearly
        Navigator.pop(context);

        _showToast(
          context,
          'Refresh failed: $e',
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFFF5252),
        );
      }
    } finally {
      // We don't need setState here because we popped the context,
      // but good practice if we decided to keep it open.
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final updateManager = ref.read(updateManagerProvider);
      final release = await updateManager.checkForUpdates();

      if (mounted) {
        // FIX: Close the sheet first so Dialogs/Toasts appear on the MainScreen context
        Navigator.pop(context);

        if (release != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            useRootNavigator: true, // Forces dialog on top of everything
            builder: (ctx) => UpdateAvailableDialog(release: release),
          );
        } else {
          _showToast(
            context,
            'You are on the latest version.',
            icon: Icons.verified_rounded,
            iconColor: Colors.blueAccent,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close sheet to show error
        _showToast(
          context,
          'Update check failed: $e',
          icon: Icons.wifi_off_rounded,
          iconColor: const Color(0xFFFF5252),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  void _showToast(
    BuildContext context,
    String message, {
    IconData? icon,
    Color? iconColor,
  }) {
    // ScaffoldMessenger finds the nearest Scaffold (MainScreen).
    // If SettingsSheet is open, this renders BEHIND it.
    // That's why we pop() before calling this.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? Colors.white, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final autoDownload = ref.watch(autoDownloadProvider);
    final cacheSizeAsync = ref.watch(cacheSizeProvider);
    final maxConcurrent = ref.watch(maxConcurrentDownloadsProvider);
    final preloadCount = ref.watch(preloadCountProvider);
    final packageInfoAsync = ref.watch(packageInfoProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          // --- LIBRARY & STORAGE ---
          const Text(
            'Library & Storage',
            style: TextStyle(
              color: Color(0xFFFF5252),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync_rounded, color: Colors.white),
                  title: const Text(
                    'Refresh Library',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Pull latest changes from tracker',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  trailing: _isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF5252),
                          ),
                        )
                      : const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white54,
                        ),
                  onTap: _isRefreshing ? null : _refreshLibrary,
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                SwitchListTile(
                  value: autoDownload,
                  activeThumbColor: const Color(0xFFFF5252),
                  title: const Text(
                    'Auto-Download',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Automatically download songs when playing',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onChanged: (val) {
                    ref.read(autoDownloadProvider.notifier).set(val);
                  },
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                ListTile(
                  title: const Text(
                    'Preload Next Songs',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    "Prepare ${preloadCount == 0 ? 'none' : '$preloadCount song${preloadCount > 1 ? 's' : ''}'} in advance",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.white54,
                        ),
                        onPressed: preloadCount > 0
                            ? () => ref
                                  .read(preloadCountProvider.notifier)
                                  .set(preloadCount - 1)
                            : null,
                      ),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '$preloadCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white54,
                        ),
                        onPressed: preloadCount < 10
                            ? () => ref
                                  .read(preloadCountProvider.notifier)
                                  .set(preloadCount + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                ListTile(
                  title: const Text(
                    'Concurrent Downloads',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Limit simultaneous downloads (Currently: $maxConcurrent)',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.white54,
                        ),
                        onPressed: maxConcurrent > 1
                            ? () => ref
                                  .read(maxConcurrentDownloadsProvider.notifier)
                                  .set(maxConcurrent - 1)
                            : null,
                      ),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '$maxConcurrent',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white54,
                        ),
                        onPressed: maxConcurrent < 5
                            ? () => ref
                                  .read(maxConcurrentDownloadsProvider.notifier)
                                  .set(maxConcurrent + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                ListTile(
                  title: const Text(
                    'Clear Cache',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    "Frees up space (Currently used: ${cacheSizeAsync.value ?? 'Calculating...'})",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.delete_outline,
                    color: Colors.white54,
                  ),
                  onTap: () async {
                    // FIX: Use useRootNavigator: true to show dialog ABOVE the sheet
                    final confirm = await showDialog<bool>(
                      context: context,
                      useRootNavigator: true,
                      builder: (c) => AlertDialog(
                        backgroundColor: const Color(0xFF252525),
                        title: const Text(
                          'Clear Cache?',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'This will delete all downloaded songs.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Color(0xFFFF5252)),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      // FIX: Close the sheet first
                      if (context.mounted) Navigator.pop(context);

                      await CacheManager.clearAllCache();
                      ref.invalidate(cacheSizeProvider);
                      ref.invalidate(tracksProvider);

                      // Show Toast on MainScreen
                      if (context.mounted) {
                        _showToast(
                          context,
                          'Cache cleared',
                          icon: Icons.delete_sweep_rounded,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- DATA SOURCE ---
          const Text(
            'Data Source',
            style: TextStyle(
              color: Color(0xFFFF5252),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sourceController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      labelText: 'Tracker Domain',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(sourceUrlProvider.notifier).state =
                        _sourceController.text;
                    ref.invalidate(tabsProvider);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Color(0xFFFF5252)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- ABOUT / UPDATES ---
          const Text(
            'About',
            style: TextStyle(
              color: Color(0xFFFF5252),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.system_update_rounded,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Check for Updates',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: packageInfoAsync.when(
                    data: (info) => Text(
                      'Current Version: ${info.version}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    loading: () => const Text(
                      'Loading version...',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    error: (_, __) => const Text(
                      'Version unknown',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  trailing: _isCheckingUpdate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF5252),
                          ),
                        )
                      : const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white54,
                        ),
                  onTap: _isCheckingUpdate ? null : _checkForUpdates,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Ye Tracker',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
