# Ye Tracker

A native Android app to listen to and organize tracks from the Ye tracker. Download music for offline playback with local storage and background audio support.

## Features

- 🎵 **Browse & Search**: Explore Ye's complete discography organized by era
- 📥 **Download Music**: Download tracks for offline playback
- ▶️ **Audio Player**: Background audio playback with playback controls
- 📱 **Playlists**: Create and manage custom playlists
- 💾 **Local Storage**: All data stored locally using Hive
- 🎨 **Dark Theme**: Beautiful dark UI optimized for music listening

## Supported Platforms

- **Android 7.0+** (API level 24+)

## Requirements

- ~50MB storage space for app and cached data

## Installation

### Download APK

Get the latest APK from [Releases](https://github.com/ameenalasady/ye_tracker_app/releases).

### Build from Source

1. Clone the repository:

   ```bash
   git clone https://github.com/ameenalasady/ye_tracker_app.git
   cd ye_tracker_app
   ```

2. Ensure Flutter 3.10.7+ is installed:

   ```bash
   flutter --version
   ```

3. Install dependencies:

   ```bash
   flutter pub get
   ```

4. Generate Hive models:

   ```bash
   dart run build_runner build
   ```

5. Connect an Android device or emulator, then run:

   ```bash
   flutter run --release
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models (Track, Playlist, SheetTab)
├── services/                 # Business logic (Audio, Downloads, Parser)
├── repositories/             # Data layer
├── providers/                # Riverpod state management
└── ui/
    ├── screens/              # Main app screens
    ├── sheets/               # Bottom sheets (playlists, settings, etc)
    └── widgets/              # Reusable UI components
```

## Configuration

The app uses a data source URL (typically a public Google Sheets tracker) to fetch Ye's music information. This is configurable in the app settings.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This application is a fan project and is not affiliated with, endorsed by, or associated with Ye, Yeezy, or any related organizations.
