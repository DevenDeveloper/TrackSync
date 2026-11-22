import 'package:sqflite/sqflite.dart';
import '../domain/location_point.dart';
import '../domain/tracking_repository.dart';

class LocationStore {
  LocationStore(this.database);
  final Database database;

  static Future<LocationStore> open(
      {DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? '${await dbFactory.getDatabasesPath()}/tracksync.db';
    final db = await dbFactory.openDatabase(dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE locations (id TEXT PRIMARY KEY, '
                'latitude REAL NOT NULL, longitude REAL NOT NULL, recordedAt TEXT NOT NULL, '
                'synced INTEGER NOT NULL DEFAULT 0)');
            await db.execute(
                'CREATE INDEX pending_locations ON locations(synced, recordedAt)');
            // Separate durable receipts emulate server-side idempotency in the demo.
            await db.execute(
                'CREATE TABLE mock_receipts (id TEXT PRIMARY KEY, payload TEXT NOT NULL)');
          },
        ));
    return LocationStore(db);
  }

  Future<void> save(LocationPoint point) async {
    await database.insert('locations', point.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<LocationPoint>> pending() async => (await database.query(
        'locations',
        where: 'synced = 0',
        orderBy: 'recordedAt ASC',
        limit: 100,
      ))
          .map(LocationPoint.fromJson)
          .toList();

  Future<void> acknowledge(String id) async {
    await database.update('locations', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<TrackingSnapshot> snapshot() => database.transaction((txn) async {
        final counts = await txn.rawQuery(
            'SELECT synced, COUNT(*) AS total FROM locations GROUP BY synced');
        int pending = 0, synced = 0;
        for (final row in counts) {
          if (row['synced'] == 0) {
            pending = row['total'] as int;
          } else {
            synced = row['total'] as int;
          }
        }
        final rows =
            await txn.query('locations', orderBy: 'recordedAt DESC', limit: 20);
        return TrackingSnapshot(
            recent: rows.map(LocationPoint.fromJson).toList(),
            pending: pending,
            synced: synced);
      });
}
