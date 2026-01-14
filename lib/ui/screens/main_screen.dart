import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../models/track.dart';
import '../../providers/app_providers.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_list.dart';

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
                              onPressed: () => _showSourceDialog(context),
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
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search tracks...",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.3)),
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
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
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
                                ? [BoxShadow(color: const Color(0xFFFF5252).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))]
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
                error: (_, __) => const SizedBox.shrink(),
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

  void _showSourceDialog(BuildContext context) {
    final controller = TextEditingController(text: ref.read(sourceUrlProvider));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text("Set Source", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Domain",
            hintText: "yetracker.net",
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF5252))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              ref.read(sourceUrlProvider.notifier).state = controller.text;
              ref.invalidate(tabsProvider);
              Navigator.pop(ctx);
            },
            child: const Text("Save", style: TextStyle(color: Color(0xFFFF5252))),
          ),
        ],
      ),
    );
  }
}