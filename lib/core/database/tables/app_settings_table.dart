import 'package:drift/drift.dart';

class AppSettings extends Table {
  TextColumn get key => text()();
  BlobColumn get value => blob()();

  @override
  Set<Column> get primaryKey => {key};
}
