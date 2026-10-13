import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'sqlite_schema.dart';

/// A safe, content-free failure. Callers can offer retry/support; they must not
/// delete or recreate the existing learner database after this error.
final class UnsupportedSqliteSchema implements Exception {
  const UnsupportedSqliteSchema(this.foundVersion);

  final int foundVersion;

  @override
  String toString() => 'Unsupported local database schema version.';
}

/// Opens Android app-private SQLite storage. Supply an isolated filename in
/// tests; production composition must supply its own stable filename.
///
/// This establishes schema v1 only. Approved-content import, later migrations,
/// session recovery and reset belong to later repository work.
Future<Database> openPilotSqliteDatabase({required String path}) async {
  if (path.trim().isEmpty || !p.isAbsolute(path)) {
    throw ArgumentError.value(path, 'path', 'Use an absolute database path.');
  }
  return openDatabase(
    path,
    version: sqliteSchemaVersion,
    onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, version) async => createSqliteSchemaV1(db),
    onUpgrade: (db, oldVersion, newVersion) async {
      throw UnsupportedSqliteSchema(oldVersion);
    },
    onDowngrade: (db, oldVersion, newVersion) async {
      throw UnsupportedSqliteSchema(oldVersion);
    },
  );
}
