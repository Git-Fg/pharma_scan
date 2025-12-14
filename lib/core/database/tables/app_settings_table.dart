import 'package:drift/drift.dart';

class AppSettings extends Table {
  TextColumn get key => text().customConstraint('PRIMARY KEY')();
  BlobColumn get value => blob()();

  @override
  Set<Column> get primaryKey => {key};
}
