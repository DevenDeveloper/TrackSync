import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../domain/location_point.dart';
import '../domain/tracking_repository.dart';

class SimulatedLocationSource implements LocationSource {
  int _step = 0;
  @override
  Stream<LocationPoint> positions() =>
      Stream<LocationPoint>.multi((controller) {
        void record() {
          final angle = _step++ * .12;
          controller.add(LocationPoint(
              id: const Uuid().v4(),
              latitude: 12.9716 + sin(angle) * .003,
              longitude: 77.5946 + cos(angle) * .004,
              recordedAt: DateTime.now().toUtc()));
        }

        record();
        final timer =
            Timer.periodic(const Duration(seconds: 3), (_) => record());
        controller.onCancel = timer.cancel;
      });
}

class DeviceConnectivity implements ConnectivitySource {
  final Connectivity _connectivity = Connectivity();
  bool _available(List<ConnectivityResult> result) =>
      result.any((item) => item != ConnectivityResult.none);
  @override
  Future<bool> get isOnline async =>
      _available(await _connectivity.checkConnectivity());
  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(_available).distinct();
}
