import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../screens/downloads_screen.dart';

class MainHeader extends ConsumerStatefulWidget {
  final VoidCallback onPlaylistsTap;
  final VoidCallback onFilterTap;
  final VoidCallback onSettingsTap;

  const MainHeader({
    super.key,
    required this.onPlaylistsTap,
    required this.onFilterTap,
    required this.onSettingsTap,
  });

  @override
  ConsumerState<MainHeader> createState() => _MainHeaderState();
}

class _MainHeaderState extends ConsumerState<MainHeader> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeEras = ref.watch(selectedErasProvider);
    final currentSort = ref.watch(sortOptionProvider);
    final activeDownloads = ref.watch(activeDownloadsProvider).value ?? {};

    final isFilterActive =
        activeEras.isNotEmpty || currentSort != SortOption.defaultOrder;

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
                  // DOWNLOADS BUTTON (NEW)
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DownloadsScreen(),
                            ),
                          );
                        },
                      ),
                      if (activeDownloads.isNotEmpty)
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
                    icon: const Icon(
                      Icons.library_music_rounded,
                      color: Colors.white54,
                    ),
                    onPressed: widget.onPlaylistsTap,
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.filter_list_rounded,
                          color: isFilterActive
                              ? const Color(0xFFFF5252)
                              : Colors.white54,
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
                    icon: const Icon(
                      Icons.settings_rounded,
                      color: Colors.white54,
                    ),
                    onPressed: widget.onSettingsTap,
                  ),
                ],
              ),
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
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search tracks...",
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                          ref.read(searchQueryProvider.notifier).state = "";
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (val) =>
                  ref.read(searchQueryProvider.notifier).state = val,
            ),
          ),
        ],
      ),
    );
  }
}
