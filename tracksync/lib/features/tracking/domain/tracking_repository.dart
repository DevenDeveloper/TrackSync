import 'location_point.dart';

class TrackingSnapshot {
  const TrackingSnapshot(
      {this.recent = const [], this.pending = 0, this.synced = 0});
  final List<LocationPoint> recent;
  final int pending;
  final int synced;
}

abstract interface class TrackingRepository {
  Future<void> save(LocationPoint point);
  Future<TrackingSnapshot> snapshot();
  Future<int> synchronize();
}

abstract interface class LocationSource {
  Stream<LocationPoint> positions();
}

abstract interface class ConnectivitySource {
  Future<bool> get isOnline;
  Stream<bool> get changes;
}
