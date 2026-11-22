import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/location_point.dart';

class LocationApi {
  LocationApi(this.client, this.endpoint);
  final http.Client client;
  final Uri endpoint;

  Future<void> upload(LocationPoint point) async {
    final response = await client
        .post(endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Idempotency-Key': point.id,
            },
            body: jsonEncode(point.toJson()))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError('Upload returned HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['id'] != point.id || body['accepted'] != true) {
      throw StateError('Server did not acknowledge this location');
    }
  }
}

/// In-process REST transport: no network or separate server setup required.
/// Receipts persist independently of the outbox's acknowledgment flag.
http.Client mockLocationClient(Database database) =>
    MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (request.method != 'POST' || request.url.path != '/locations') {
        return http.Response('Not found', 404);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final id = body['id'] as String;
      if (request.headers['Idempotency-Key'] != id &&
          request.headers['idempotency-key'] != id) {
        return http.Response('Invalid idempotency key', 400);
      }
      await database.insert(
          'mock_receipts', {'id': id, 'payload': request.body},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      return http.Response(jsonEncode({'id': id, 'accepted': true}), 200,
          headers: {'content-type': 'application/json'});
    });
