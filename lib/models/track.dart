import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class Track extends HiveObject {
  @HiveField(0)
  final String era;
  @HiveField(1)
  final String artist;
  @HiveField(2)
  final String title;
  @HiveField(3)
  final String notes;
  @HiveField(4)
  final String length;
  @HiveField(5)
  final String releaseDate;
  @HiveField(6)
  final String type;
  @HiveField(7)
  final bool isStreaming;
  @HiveField(8)
  final String link;
  @HiveField(9)
  String localPath;
  @HiveField(10)
  final String albumArtUrl; // Added field

  // Cached lowercased string for O(1) access during search filtering
  String? _searchIndex;

  Track({
    required this.era,
    required this.artist,
    required this.title,
    required this.notes,
    required this.length,
    required this.releaseDate,
    required this.type,
    required this.isStreaming,
    required this.link,
    this.localPath = '',
    this.albumArtUrl = '',
  });

  Track copyWith({String? localPath}) {
    return Track(
      era: era,
      artist: artist,
      title: title,
      notes: notes,
      length: length,
      releaseDate: releaseDate,
      type: type,
      isStreaming: isStreaming,
      link: link,
      localPath: localPath ?? this.localPath,
      albumArtUrl: albumArtUrl,
    );
  }

  String get displayName => artist.isNotEmpty ? "$artist - $title" : title;

  String get searchIndex {
    _searchIndex ??= "$title $artist $era $notes".toLowerCase();
    return _searchIndex!;
  }

  /// Centralized logic to get the actual download/stream URL
  String get effectiveUrl {
    if (link.contains('pillows.su/f/')) {
      try {
        final cleanUri = Uri.parse(link).replace(query: '').toString();
        final id = cleanUri.split('/f/').last.replaceAll('/', '');
        return 'https://api.pillows.su/api/download/$id.mp3';
      } catch (e) {
        return link;
      }
    }
    return link;
  }
}

class TrackAdapter extends TypeAdapter<Track> {
  @override
  final int typeId = 1;

  @override
  Track read(BinaryReader reader) {
    return Track(
      era: reader.read(),
      artist: reader.read(),
      title: reader.read(),
      notes: reader.read(),
      length: reader.read(),
      releaseDate: reader.read(),
      type: reader.read(),
      isStreaming: reader.read(),
      link: reader.read(),
      localPath: reader.read(),
      albumArtUrl: reader.read(), // Read new field
    );
  }

  @override
  void write(BinaryWriter writer, Track obj) {
    writer.write(obj.era);
    writer.write(obj.artist);
    writer.write(obj.title);
    writer.write(obj.notes);
    writer.write(obj.length);
    writer.write(obj.releaseDate);
    writer.write(obj.type);
    writer.write(obj.isStreaming);
    writer.write(obj.link);
    writer.write(obj.localPath);
    writer.write(obj.albumArtUrl); // Write new field
  }
}