import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tracksync/features/tracking/data/location_api.dart';
import 'package:tracksync/features/tracking/data/location_store.dart';
import 'package:tracksync/features/tracking/data/offline_tracking_repository.dart';
import 'package:tracksync/features/tracking/domain/location_point.dart';

LocationPoint point(String id) => LocationPoint(
    id: id,
    latitude: 12.97,
    longitude: 77.59,
    recordedAt: DateTime.utc(2026, 1, 1));

void main() {
  sqfliteFfiInit();
  late LocationStore store;
  final endpoint = Uri.parse('https://mock.tracksync.local/locations');
  setUp(() async {
    store = await LocationStore.open(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });
  tearDown(() async {
    await store.database.close();
  });

  test('offline points survive closing and reopening SQLite', () async {
    final dir = await Directory.systemTemp.createTemp('tracksync_test');
    try {
      final path = '${dir.path}/queue.db';
      final first =
          await LocationStore.open(factory: databaseFactoryFfi, path: path);
      await first.save(point('durable'));
      await first.database.close();
      final reopened =
          await LocationStore.open(factory: databaseFactoryFfi, path: path);
      expect((await reopened.pending()).single.id, 'durable');
      await reopened.database.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('duplicate local insert does not reset a synced location', () async {
    await store.save(point('one'));
    await store.acknowledge('one');
    await store.save(point('one'));
    expect((await store.snapshot()).synced, 1);
    expect((await store.snapshot()).pending, 0);
  });

  test('failed upload stays pending and retries with the same ID', () async {
    final ids = <String>[];
    final client = MockClient((request) async {
      final id =
          (jsonDecode(request.body) as Map<String, dynamic>)['id'] as String;
      ids.add(id);
      return ids.length == 1
          ? http.Response('unavailable', 503)
          : http.Response(jsonEncode({'id': id, 'accepted': true}), 200);
    });
    final repo =
        OfflineTrackingRepository(store, LocationApi(client, endpoint));
    await repo.save(point('retry'));
    await expectLater(repo.synchronize(), throwsStateError);
    expect((await repo.snapshot()).pending, 1);
    expect(await repo.synchronize(), 1);
    expect(ids, ['retry', 'retry']);
    expect((await repo.snapshot()).synced, 1);
    client.close();
  });

  test('lost response after server acceptance does not duplicate submission',
      () async {
    final server = mockLocationClient(store.database);
    var loseResponse = true;
    final client = MockClient((request) async {
      final response = await server.post(request.url,
          headers: request.headers, body: request.body);
      if (loseResponse) {
        loseResponse = false;
        throw const SocketException('response lost');
      }
      return response;
    });
    final repo =
        OfflineTrackingRepository(store, LocationApi(client, endpoint));
    await repo.save(point('stable-id'));
    await expectLater(repo.synchronize(), throwsA(isA<SocketException>()));
    expect((await repo.snapshot()).pending, 1);
    await repo.synchronize();
    expect(await store.database.query('mock_receipts'), hasLength(1));
    expect((await repo.snapshot()).synced, 1);
    client.close();
    server.close();
  });

  test('concurrent sync requests share one upload', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return http.Response(jsonEncode({'id': 'one', 'accepted': true}), 200);
    });
    final repo =
        OfflineTrackingRepository(store, LocationApi(client, endpoint));
    await repo.save(point('one'));
    await Future.wait(
        [repo.synchronize(), repo.synchronize(), repo.synchronize()]);
    expect(requests, 1);
    client.close();
  });

  test('wrong acknowledgment never removes a queued point', () async {
    final client = MockClient(
        (_) async => http.Response('{"id":"wrong","accepted":true}', 200));
    final repo =
        OfflineTrackingRepository(store, LocationApi(client, endpoint));
    await repo.save(point('one'));
    await expectLater(repo.synchronize(), throwsStateError);
    expect((await repo.snapshot()).pending, 1);
    client.close();
  });

  test('partial batch failure preserves only the unacknowledged points',
      () async {
    final client = MockClient((request) async {
      final id = (jsonDecode(request.body) as Map<String, dynamic>)['id'];
      return id == 'one'
          ? http.Response(jsonEncode({'id': id, 'accepted': true}), 200)
          : http.Response('unavailable', 503);
    });
    final repo =
        OfflineTrackingRepository(store, LocationApi(client, endpoint));
    await repo.save(point('one'));
    await repo.save(point('two'));
    await expectLater(repo.synchronize(), throwsStateError);
    expect((await repo.snapshot()).synced, 1);
    expect((await store.pending()).single.id, 'two');
    client.close();
  });
}
