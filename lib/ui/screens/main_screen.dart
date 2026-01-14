import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../models/track.dart';
import '../../providers/app_providers.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_list.dart';
import 'player_screen.dart'; // Import added

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late final TextEditingController _searchController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 500));

    if (ref.read(selectedTabProvider) != null) {
      final tab = ref.read(selectedTabProvider)!;
      final boxName = 'tracks_${tab.gid}';
      if (Hive.isBoxOpen(boxName)) await Hive.box<Track>(boxName).clear();
      ref.invalidate(tracksProvider);
    } else {
      ref.invalidate(tabsProvider);
    }
    // Refresh cache size calculation
    ref.invalidate(cacheSizeProvider);

    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final tabsAsync = ref.watch(tabsProvider);
    final selectedTab = ref.watch(selectedTabProvider);

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 50), // Top spacing for status bar

              // --- HEADER & SEARCH ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Ye Tracker",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: _isRefreshing
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                                : const Icon(Icons.refresh_rounded, color: Colors.white54),
                              onPressed: _isRefreshing ? null : _refresh,
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_rounded, color: Colors.white54),
                              onPressed: () => _showSettingsSheet(context),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Modern Search Bar
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search tracks...",
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.3)),
                          suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(searchQueryProvider.notifier).state = "";
                                },
                              )
                            : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- TABS ---
              tabsAsync.when(
                data: (tabs) {
                  if (selectedTab == null && tabs.isNotEmpty) {
                    Future.microtask(() => ref.read(selectedTabProvider.notifier).state = tabs.first);
                    return const SizedBox(height: 40);
                  }

                  return SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: tabs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (ctx, index) {
                        final tab = tabs[index];
                        final isSelected = tab == selectedTab;
                        return GestureDetector(
                          onTap: () {
                            ref.read(selectedTabProvider.notifier).state = tab;
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).state = "";
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                ? const LinearGradient(colors: [Color(0xFFFF7E5F), Color(0xFFFF5252)])
                                : const LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF2A2A2A)]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected
                                ? [BoxShadow(color: const Color(0xFFFF5252).withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]
                                : [],
                            ),
                            child: Center(
                              child: Text(
                                tab.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white60,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const SizedBox(height: 40),
                error: (_, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 10),

              // --- TRACK LIST ---
              const Expanded(child: TrackList()),
            ],
          ),

          // --- FLOATING PLAYER ---
          const Align(
            alignment: Alignment.bottomCenter,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }

  // --- SETTINGS SHEET ---
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
}

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  late TextEditingController _sourceController;

  @override
  void initState() {
    super.initState();
    _sourceController = TextEditingController(text: ref.read(sourceUrlProvider));
  }

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final autoDownload = ref.watch(autoDownloadProvider);
    final cacheSizeAsync = ref.watch(cacheSizeProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          const Text("Settings", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),

          // --- SECTION: OFFLINE ---
          const Text("Offline & Storage", style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  value: autoDownload,
                  activeThumbColor: const Color(0xFFFF5252),
                  title: const Text("Auto-Download on Play", style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Automatically save songs when you play them", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  onChanged: (val) {
                    ref.read(autoDownloadProvider.notifier).state = val;
                    Hive.box('settings').put('auto_download', val);
                  },
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                ListTile(
                  title: const Text("Clear Cache", style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    "Frees up space (Currently used: ${cacheSizeAsync.value ?? 'Calculating...'})",
                    style: const TextStyle(color: Colors.grey, fontSize: 12)
                  ),
                  trailing: const Icon(Icons.delete_outline, color: Colors.white54),
                  onTap: () async {
                    // Confirm Dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: const Color(0xFF252525),
                        title: const Text("Clear Cache?", style: TextStyle(color: Colors.white)),
                        content: const Text("This will delete all downloaded songs.", style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Color(0xFFFF5252)))),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await CacheManager.clearAllCache();
                      ref.invalidate(cacheSizeProvider); // Recalculate size
                      ref.invalidate(tracksProvider); // Refresh track lists to remove checkmarks
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cache cleared")));
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- SECTION: SOURCE ---
          const Text("Data Source", style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(16)),
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
                    ref.read(sourceUrlProvider.notifier).state = _sourceController.text;
                    ref.invalidate(tabsProvider);
                    Navigator.pop(context);
                  },
                  child: const Text("Save", style: TextStyle(color: Color(0xFFFF5252))),
                )
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Center(child: Text("v1.0.0 • Ye Tracker", style: TextStyle(color: Colors.white24, fontSize: 12))),
        ],
      ),
    );
  }
}