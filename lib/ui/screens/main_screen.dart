import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/track.dart';
import '../../models/playlist.dart';
import '../../providers/app_providers.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_list.dart';
import 'playlist_detail_screen.dart';

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

    // Aesthetic delay
    await Future.delayed(const Duration(milliseconds: 500));

    final selectedTab = ref.read(selectedTabProvider);

    if (selectedTab != null) {
      // 1. Tell Repository to clear the local cache for this tab
      await ref.read(tracksRepositoryProvider).clearLocalCache(selectedTab);
      // 2. Invalidate provider to trigger re-read (which will now fetch from network)
      ref.invalidate(tracksProvider);
    } else {
      // If no tab selected, refresh the tabs list
      ref.invalidate(tabsProvider);
    }

    // Always refresh cache size calculation
    ref.invalidate(cacheSizeProvider);

    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final tabsAsync = ref.watch(tabsProvider);
    final selectedTab = ref.watch(selectedTabProvider);

    final activeEraCount = ref.watch(selectedErasProvider).length;
    final isSortChanged = ref.watch(sortOptionProvider) != SortOption.defaultOrder;
    final isFilterActive = activeEraCount > 0 || isSortChanged;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 50),
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
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1, color: Colors.white),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.library_music_rounded, color: Colors.white54),
                              onPressed: () => _showPlaylistsSheet(context),
                            ),
                            Stack(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.filter_list_rounded, color: isFilterActive ? const Color(0xFFFF5252) : Colors.white54),
                                  onPressed: () => _showFilterSheet(context),
                                ),
                                if (isFilterActive)
                                  Positioned(
                                    right: 8, top: 8,
                                    child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF5252), shape: BoxShape.circle)),
                                  ),
                              ],
                            ),
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
              tabsAsync.when(
                data: (tabs) {
                  if (selectedTab == null && tabs.isNotEmpty) {
                    // Set initial tab without rebuilding instantly
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
                            ref.read(selectedErasProvider.notifier).state = {};
                            ref.read(sortOptionProvider.notifier).state = SortOption.defaultOrder;
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
              const Expanded(child: TrackList()),
            ],
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }

  void _showPlaylistsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => const PlaylistsSheet(),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => const FilterSheet(),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => const SettingsSheet(),
    );
  }
}

// --- NEW: PLAYLISTS SHEET ---
class PlaylistsSheet extends ConsumerWidget {
  const PlaylistsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Your Playlists", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton(
                      icon: const Icon(Icons.add, color: Color(0xFFFF5252)),
                      onPressed: () => _createPlaylistDialog(context, ref),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: playlists.isEmpty
                  ? const Center(child: Text("No playlists yet.", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: playlists.length,
                      itemBuilder: (ctx, index) {
                        final playlist = playlists[index];
                        return ListTile(
                          leading: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.music_note, color: Colors.white24),
                          ),
                          title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text("${playlist.tracks.length} tracks", style: const TextStyle(color: Colors.white54)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white30, size: 20),
                            onPressed: () => ref.read(playlistsProvider.notifier).deletePlaylist(playlist),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: playlist)));
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _createPlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text("New Playlist", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Playlist Name", hintStyle: TextStyle(color: Colors.grey)),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(playlistsProvider.notifier).createPlaylist(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Create", style: TextStyle(color: Color(0xFFFF5252))),
          )
        ],
      ),
    );
  }
}

// --- FILTER SHEET (Unchanged Logic, just context fix) ---
class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSort = ref.watch(sortOptionProvider);
    final availableEras = ref.watch(availableErasProvider);
    final selectedEras = ref.watch(selectedErasProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
             color: Color(0xFF1E1E1E),
             borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Filter & Sort", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  TextButton(
                    onPressed: () {
                      ref.read(sortOptionProvider.notifier).state = SortOption.defaultOrder;
                      ref.read(selectedErasProvider.notifier).state = {};
                      Navigator.pop(context);
                    },
                    child: const Text("Reset", style: TextStyle(color: Color(0xFFFF5252))),
                  )
                ],
              ),
              const SizedBox(height: 24),
              const Text("Sort By", style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [
                  _buildSortChip(ref, currentSort, SortOption.defaultOrder, "Default"),
                  _buildSortChip(ref, currentSort, SortOption.newest, "Newest"),
                  _buildSortChip(ref, currentSort, SortOption.oldest, "Oldest"),
                  _buildSortChip(ref, currentSort, SortOption.nameAz, "Name (A-Z)"),
                  _buildSortChip(ref, currentSort, SortOption.shortest, "Shortest"),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 24),
              const Text("Filter Eras", style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              availableEras.isEmpty
              ? const Text("No eras found in this tab.", style: TextStyle(color: Colors.grey))
              : Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                   ChoiceChip(
                     label: const Text("All Eras"),
                     selected: selectedEras.isEmpty,
                     onSelected: (selected) { if (selected) ref.read(selectedErasProvider.notifier).state = {}; },
                     backgroundColor: const Color(0xFF2A2A2A),
                     selectedColor: const Color(0xFFFF5252),
                     labelStyle: TextStyle(color: selectedEras.isEmpty ? Colors.white : Colors.white),
                     side: BorderSide.none,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                   ),
                   ...availableEras.map((era) {
                     final isSelected = selectedEras.contains(era);
                     return FilterChip(
                       label: Text(era),
                       selected: isSelected,
                       onSelected: (bool selected) {
                         final current = Set<String>.from(ref.read(selectedErasProvider));
                         if (selected) current.add(era); else current.remove(era);
                         ref.read(selectedErasProvider.notifier).state = current;
                       },
                       backgroundColor: const Color(0xFF2A2A2A),
                       selectedColor: const Color(0xFFFF5252).withValues(alpha: 0.6),
                       checkmarkColor: Colors.white,
                       labelStyle: const TextStyle(color: Colors.white70),
                       side: BorderSide.none,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                     );
                   }),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSortChip(WidgetRef ref, SortOption current, SortOption value, String label) {
    final isSelected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) ref.read(sortOptionProvider.notifier).state = value;
      },
      backgroundColor: const Color(0xFF2A2A2A),
      selectedColor: const Color(0xFFFF5252),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

// --- SETTINGS SHEET (Unchanged logic) ---
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
                      ref.invalidate(cacheSizeProvider);
                      ref.invalidate(tracksProvider);
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
          const Center(child: Text("v1.2.0 • Ye Tracker", style: TextStyle(color: Colors.white24, fontSize: 12))),
        ],
      ),
    );
  }
}