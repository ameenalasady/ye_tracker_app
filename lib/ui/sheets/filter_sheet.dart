import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

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
      builder: (_, scrollController) => Container(
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter & Sort',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(sortOptionProvider.notifier).state =
                        SortOption.defaultOrder;
                    ref.read(selectedErasProvider.notifier).state = {};
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(color: Color(0xFFFF5252)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Sort By',
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildSortChip(
                  ref,
                  currentSort,
                  SortOption.defaultOrder,
                  'Default',
                ),
                _buildSortChip(ref, currentSort, SortOption.newest, 'Newest'),
                _buildSortChip(ref, currentSort, SortOption.oldest, 'Oldest'),
                _buildSortChip(
                  ref,
                  currentSort,
                  SortOption.nameAz,
                  'Name (A-Z)',
                ),
                _buildSortChip(
                  ref,
                  currentSort,
                  SortOption.shortest,
                  'Shortest',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24),
            const Text(
              'Filter Eras',
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            if (availableEras.isEmpty)
              const Text(
                'No eras found in this tab.',
                style: TextStyle(color: Colors.grey),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All Eras'),
                    selected: selectedEras.isEmpty,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(selectedErasProvider.notifier).state = {};
                      }
                    },
                    backgroundColor: const Color(0xFF2A2A2A),
                    selectedColor: const Color(0xFFFF5252),
                    labelStyle: TextStyle(
                      color: selectedEras.isEmpty ? Colors.white : Colors.white,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  ...availableEras.map((era) {
                    final isSelected = selectedEras.contains(era);
                    return FilterChip(
                      label: Text(era),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        final current = Set<String>.from(
                          ref.read(selectedErasProvider),
                        );
                        if (selected) {
                          current.add(era);
                        } else {
                          current.remove(era);
                        }
                        ref.read(selectedErasProvider.notifier).state = current;
                      },
                      backgroundColor: const Color(0xFF2A2A2A),
                      selectedColor: const Color(
                        0xFFFF5252,
                      ).withValues(alpha: 0.6),
                      checkmarkColor: Colors.white,
                      labelStyle: const TextStyle(color: Colors.white70),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }),
                ],
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(
    WidgetRef ref,
    SortOption current,
    SortOption value,
    String label,
  ) {
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
