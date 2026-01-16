import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/playlist.dart';
import 'models/sheet_tab.dart';
import 'models/track.dart';
import 'providers/app_providers.dart';
import 'services/audio_handler.dart';
import 'services/download_manager.dart'; // Import
import 'ui/screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Make status bar transparent for immersive feel
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(SheetTabAdapter());
  Hive.registerAdapter(TrackAdapter());
  Hive.registerAdapter(PlaylistAdapter());

  await Hive.openBox('settings');
  await Hive.openBox<Playlist>('playlists');
  await Hive.openBox<SheetTab>('tabs');

  // Initialize Download Manager (Singleton for the app life)
  final downloadManager = DownloadManager();

  // Initialize Audio Service, injecting DownloadManager
  final audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(downloadManager), // Inject here
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.yetracker.channel.audio',
      androidNotificationChannelName: 'Ye Tracker Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: true,
      notificationColor: Color(0xFFFF5252),
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
        downloadManagerProvider.overrideWithValue(downloadManager), // Register here
      ],
      child: const YeTrackerApp(),
    ),
  );
}

class YeTrackerApp extends StatelessWidget {
  const YeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ye Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF5252),
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      home: const MainScreen(),
    );
  }
}