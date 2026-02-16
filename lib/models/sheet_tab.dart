import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class SheetTab extends HiveObject {
  SheetTab({required this.name, required this.gid});
  @HiveField(0)
  final String name;
  @HiveField(1)
  final String gid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SheetTab &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          gid == other.gid;

  @override
  int get hashCode => name.hashCode ^ gid.hashCode;
}

class SheetTabAdapter extends TypeAdapter<SheetTab> {
  @override
  final int typeId = 0;
  @override
  SheetTab read(BinaryReader reader) =>
      SheetTab(name: reader.read(), gid: reader.read());

  @override
  void write(BinaryWriter writer, SheetTab obj) {
    writer.write(obj.name);
    writer.write(obj.gid);
  }
}
