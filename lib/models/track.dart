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
  final String albumArtUrl;

  String? _searchIndex;

  static const Map<String, String> imageHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
    'Referer': 'https://docs.google.com/',
  };

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

  int get durationInSeconds {
    try {
      if (!length.contains(':')) return 0;
      final parts = length.split(':');
      if (parts.length == 2) {
        return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      } else if (parts.length == 3) {
        return (int.tryParse(parts[0]) ?? 0) * 3600 +
            (int.tryParse(parts[1]) ?? 0) * 60 +
            (int.tryParse(parts[2]) ?? 0);
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

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

  // --- ADDED: Equality Operators for Playlist Logic ---
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Track &&
        other.title == title &&
        other.artist == artist &&
        other.era == era &&
        other.link == link;
  }

  @override
  int get hashCode {
    return title.hashCode ^ artist.hashCode ^ era.hashCode ^ link.hashCode;
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
      albumArtUrl: reader.read(),
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
    writer.write(obj.albumArtUrl);
  }
}