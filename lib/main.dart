import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/sheet_tab.dart';
import 'models/track.dart';
import 'providers/app_providers.dart';
import 'services/audio_handler.dart';
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
  await Hive.openBox('settings');

  // Initialize Audio Service
  final audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.yetracker.channel.audio',
      androidNotificationChannelName: 'Ye Tracker Playback',
      androidNotificationOngoing: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
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
        scaffoldBackgroundColor: const Color(0xFF121212), // Deep dark background
        fontFamily: 'Inter', // Ensure you have a nice font, or fallback to default
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF5252), // Coral Red
          surface: Color(0xFF1E1E1E),
          background: Color(0xFF121212),
          onSurface: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      home: const MainScreen(),
    );
  }
}