import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          const Text("Settings",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          const Text("Offline & Storage",
              style: TextStyle(
                  color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  value: autoDownload,
                  activeThumbColor: const Color(0xFFFF5252),
                  title: const Text("Auto-Download on Play", style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Automatically save songs when you play them",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  onChanged: (val) {
                    ref.read(autoDownloadProvider.notifier).set(val);
                  },
                ),
                Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                ListTile(
                  title: const Text("Clear Cache", style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                      "Frees up space (Currently used: ${cacheSizeAsync.value ?? 'Calculating...'})",
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: const Icon(Icons.delete_outline, color: Colors.white54),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: const Color(0xFF252525),
                        title:
                            const Text("Clear Cache?", style: TextStyle(color: Colors.white)),
                        content: const Text("This will delete all downloaded songs.",
                            style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text("Cancel")),
                          TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text("Delete",
                                  style: TextStyle(color: Color(0xFFFF5252)))),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await CacheManager.clearAllCache();
                      ref.invalidate(cacheSizeProvider);
                      ref.invalidate(tracksProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text("Cache cleared")));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Data Source",
              style: TextStyle(
                  color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(16)),
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
          const Center(
              child: Text("v1.2.0 • Ye Tracker",
                  style: TextStyle(color: Colors.white24, fontSize: 12))),
        ],
      ),
    );
  }
}