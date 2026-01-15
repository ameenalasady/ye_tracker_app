import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

class EraTabSelector extends ConsumerWidget {
  const EraTabSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsAsync = ref.watch(tabsProvider);
    final selectedTab = ref.watch(selectedTabProvider);

    return tabsAsync.when(
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
                  // Reset filters when changing tabs
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
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF5252).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
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
    );
  }
}