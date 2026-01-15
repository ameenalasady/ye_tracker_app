import 'package:hive/hive.dart';
import 'track.dart';

@HiveType(typeId: 2)
class Playlist extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<Track> tracks;

  Playlist({
    required this.name,
    required this.tracks,
  });
}

class PlaylistAdapter extends TypeAdapter<Playlist> {
  @override
  final int typeId = 2;

  @override
  Playlist read(BinaryReader reader) {
    return Playlist(
      name: reader.read(),
      tracks: (reader.read() as List).cast<Track>(),
    );
  }

  @override
  void write(BinaryWriter writer, Playlist obj) {
    writer.write(obj.name);
    writer.write(obj.tracks);
  }
}