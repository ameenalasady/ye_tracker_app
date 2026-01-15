import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_list.dart';
import '../widgets/main_header.dart'; // Import Component
import '../widgets/era_tab_selector.dart'; // Import Component
import '../sheets/playlists_sheet.dart'; // Import Sheet
import '../sheets/filter_sheet.dart'; // Import Sheet
import '../sheets/settings_sheet.dart'; // Import Sheet

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  bool _isRefreshing = false;

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 50),
              // --- Component: Header ---
              MainHeader(
                isRefreshing: _isRefreshing,
                onRefresh: _refresh,
                onPlaylistsTap: () => _showPlaylistsSheet(context),
                onFilterTap: () => _showFilterSheet(context),
                onSettingsTap: () => _showSettingsSheet(context),
              ),
              const SizedBox(height: 16),
              // --- Component: Tab Selector ---
              const EraTabSelector(),
              const SizedBox(height: 10),
              // --- Component: Track List (Already existed) ---
              const Expanded(child: TrackList()),
            ],
          ),
          // --- Component: Mini Player (Already existed) ---
          const Align(
            alignment: Alignment.bottomCenter,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }
}