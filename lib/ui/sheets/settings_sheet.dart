import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  late TextEditingController _sourceController;
  bool _isRefreshing = false;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Library refreshed successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Refresh failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoDownload = ref.watch(autoDownloadProvider);
    final cacheSizeAsync = ref.watch(cacheSizeProvider);
    final maxConcurrent = ref.watch(maxConcurrentDownloadsProvider);
    final preloadCount = ref.watch(preloadCountProvider);
    // Watch package info to get version from GitHub Actions build
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
            "Settings",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          // --- LIBRARY & STORAGE ---
          const Text(
            "Library & Storage",
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
                    "Refresh Library",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    "Pull latest changes from tracker",
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
                    "Auto-Download",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    "Automatically download songs when playing",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onChanged: (val) {
                    ref.read(autoDownloadProvider.notifier).set(val);
                  },
                ),
                // --- NEW: Preload Count Setting ---
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                ListTile(
                  title: const Text(
                    "Preload Next Songs",
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
                          "$preloadCount",
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
                // ----------------------------------
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                ListTile(
                  title: const Text(
                    "Concurrent Downloads",
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    "Limit simultaneous downloads (Currently: $maxConcurrent)",
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
                          "$maxConcurrent",
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
                    "Clear Cache",
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
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: const Color(0xFF252525),
                        title: const Text(
                          "Clear Cache?",
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          "This will delete all downloaded songs.",
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text(
                              "Delete",
                              style: TextStyle(color: Color(0xFFFF5252)),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await CacheManager.clearAllCache();
                      ref.invalidate(cacheSizeProvider);
                      ref.invalidate(tracksProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Cache cleared")),
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
            "Data Source",
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
                      labelText: "Tracker Domain",
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
                    "Save",
                    style: TextStyle(color: Color(0xFFFF5252)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              packageInfoAsync.when(
                data: (info) => "${info.version} • Ye Tracker",
                loading: () => "Loading... • Ye Tracker",
                error: (_, __) => "Ye Tracker",
              ),
              style: const TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
