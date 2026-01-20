import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/mini_player.dart';
import '../widgets/track_list.dart';
import '../widgets/main_header.dart';
import '../widgets/era_tab_selector.dart';
import '../sheets/playlists_sheet.dart';
import '../sheets/filter_sheet.dart';
import '../sheets/settings_sheet.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {

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
          const Align(
            alignment: Alignment.bottomCenter,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }
}