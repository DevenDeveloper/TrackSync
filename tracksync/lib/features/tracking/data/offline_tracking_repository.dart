import '../domain/location_point.dart';
import '../domain/tracking_repository.dart';
import 'location_api.dart';
import 'location_store.dart';

class OfflineTrackingRepository implements TrackingRepository {
  OfflineTrackingRepository(this.store, this.api);
  final LocationStore store;
  final LocationApi api;
  Future<int>? _inFlight;

  @override
  Future<void> save(LocationPoint point) => store.save(point);
  @override
  Future<TrackingSnapshot> snapshot() => store.snapshot();

  // All callers share one drain, preventing overlapping uploads.
  @override
  Future<int> synchronize() =>
      _inFlight ??= _drain().whenComplete(() => _inFlight = null);

  Future<int> _drain() async {
    var count = 0;
    // One bounded batch per attempt; the BLoC schedules remaining work.
    for (final point in await store.pending()) {
      await api.upload(point);
      // A crash here is safe: a retry uses the same server idempotency key.
      await store.acknowledge(point.id);
      count++;
    }
    return count;
  }
}
