import 'package:ace_naplan5/infrastructure/persistence/sqlite_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opener rejects missing and relative paths before invoking SQLite',
      () async {
    for (final path in ['', 'relative.db']) {
      await expectLater(
        openPilotSqliteDatabase(path: path),
        throwsArgumentError,
      );
    }
  });

  test('unsupported schema error contains no learner data', () {
    expect(const UnsupportedSqliteSchema(2).toString(),
        'Unsupported local database schema version.');
  });
}
