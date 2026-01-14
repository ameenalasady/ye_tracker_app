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

  @override
  Widget build(BuildContext context) {
    final tabsAsync = ref.watch(tabsProvider);
    final selectedTab = ref.watch(selectedTabProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Ye Tracker",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: () => _showSourceDialog(context),
            tooltip: 'Change Source',
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing
                ? null
                : () async {
                    setState(() => _isRefreshing = true);

                    // Slight delay to ensure UI updates and "feels" like a refresh
                    await Future.delayed(const Duration(milliseconds: 500));

                    if (ref.read(selectedTabProvider) != null) {
                      final tab = ref.read(selectedTabProvider)!;
                      final boxName = 'tracks_${tab.gid}';
                      if (Hive.isBoxOpen(boxName))
                        await Hive.box<Track>(boxName).clear();
                      ref.invalidate(tracksProvider);
                    } else {
                      ref.invalidate(tabsProvider);
                    }

                    if (mounted) setState(() => _isRefreshing = false);
                  },
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: "Search tracks, eras, notes...",
              leading: const Icon(Icons.search, color: Colors.grey),
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(const Color(0xFF333333)),
              textStyle: WidgetStateProperty.all(
                const TextStyle(color: Colors.white),
              ),
              onChanged: (val) =>
                  ref.read(searchQueryProvider.notifier).state = val,
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(searchQueryProvider.notifier).state = "";
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      body: tabsAsync.when(
        data: (tabs) {
          if (selectedTab == null && tabs.isNotEmpty) {
            // Select first tab by default without scheduling a rebuild during build
            Future.microtask(
              () => ref.read(selectedTabProvider.notifier).state = tabs.first,
            );
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Container(
                height: 50,
                color: const Color(0xFF1E1E1E),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: tabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, index) {
                    final tab = tabs[index];
                    final isSelected = tab == selectedTab;
                    return ChoiceChip(
                      label: Text(tab.name),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) {
                          ref.read(selectedTabProvider.notifier).state = tab;
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = "";
                        }
                      },
                      showCheckmark: false,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  },
                ),
              ),
              const Expanded(child: TrackList()),
              const MiniPlayer(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text("Connection Error.\n$err", textAlign: TextAlign.center),
        ),
      ),
    );
  }

  void _showSourceDialog(BuildContext context) {
    final controller = TextEditingController(text: ref.read(sourceUrlProvider));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Set Source"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Domain",
            hintText: "yetracker.net",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              ref.read(sourceUrlProvider.notifier).state = controller.text;
              ref.invalidate(tabsProvider);
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
