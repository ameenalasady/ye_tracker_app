import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

class MainHeader extends ConsumerStatefulWidget {
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onPlaylistsTap;
  final VoidCallback onFilterTap;
  final VoidCallback onSettingsTap;

  const MainHeader({
    super.key,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onPlaylistsTap,
    required this.onFilterTap,
    required this.onSettingsTap,
  });

  @override
  ConsumerState<MainHeader> createState() => _MainHeaderState();
}

class _MainHeaderState extends ConsumerState<MainHeader> {
  late final TextEditingController _searchController;

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
    // Watch these to show the little red dot on the filter icon
    final activeEraCount = ref.watch(selectedErasProvider).length;
    final isSortChanged = ref.watch(sortOptionProvider) != SortOption.defaultOrder;
    final isFilterActive = activeEraCount > 0 || isSortChanged;

    // Listen to external changes to search query (e.g. from Tab change clearing it)
    ref.listen(searchQueryProvider, (previous, next) {
      if (next.isEmpty && _searchController.text.isNotEmpty) {
        _searchController.clear();
      }
    });

    return Padding(
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
                    icon: const Icon(Icons.library_music_rounded, color: Colors.white54),
                    onPressed: widget.onPlaylistsTap,
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.filter_list_rounded,
                          color: isFilterActive ? const Color(0xFFFF5252) : Colors.white54,
                        ),
                        onPressed: widget.onFilterTap,
                      ),
                      if (isFilterActive)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5252),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: widget.isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                          )
                        : const Icon(Icons.refresh_rounded, color: Colors.white54),
                    onPressed: widget.isRefreshing ? null : widget.onRefresh,
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded, color: Colors.white54),
                    onPressed: widget.onSettingsTap,
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
    );
  }
}