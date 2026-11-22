import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracksync/features/tracking/domain/location_point.dart';
import 'package:tracksync/features/tracking/domain/tracking_repository.dart';
import 'package:tracksync/features/tracking/presentation/tracking_bloc.dart';
import 'package:tracksync/features/tracking/presentation/tracking_page.dart';

class MemoryRepository implements TrackingRepository {
  final points = <LocationPoint>[];
  int synced = 0;
  @override
  Future<void> save(LocationPoint point) async {
    points.add(point);
  }

  @override
  Future<TrackingSnapshot> snapshot() async =>
      TrackingSnapshot(pending: points.length - synced, synced: synced);
  @override
  Future<int> synchronize() async {
    final count = points.length - synced;
    synced = points.length;
    return count;
  }
}

class TestLocations implements LocationSource {
  final controller = StreamController<LocationPoint>(onCancel: () async {});
  @override
  Stream<LocationPoint> positions() => controller.stream;
}

class TestConnection implements ConnectivitySource {
  final controller = StreamController<bool>.broadcast();
  @override
  Future<bool> get isOnline async => true;
  @override
  Stream<bool> get changes => controller.stream;
}

void main() {
  testWidgets('start, store offline, reconnect automatically, and stop',
      (tester) async {
    final repository = MemoryRepository();
    final locations = TestLocations();
    final connectivity = TestConnection();
    final bloc = TrackingBloc(repository, locations, connectivity)
      ..add(InitializeTracking());
    await tester.pumpWidget(MaterialApp(
        home: BlocProvider.value(value: bloc, child: const TrackingPage())));
    await tester.pumpAndSettle();
    expect(find.text('Every stop. In sync.'), findsOneWidget);
    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle();
    expect(bloc.state.tracking, isTrue);
    bloc.add(SetOffline(true));
    await tester.pumpAndSettle();
    locations.controller.add(LocationPoint(
        id: 'test-location',
        latitude: 1,
        longitude: 2,
        recordedAt: DateTime.utc(2026)));
    await tester.pumpAndSettle();
    expect(bloc.state.snapshot.pending, 1);
    expect(repository.synced, 0);
    bloc.add(SetOffline(false));
    await tester.pumpAndSettle();
    expect(bloc.state.snapshot.pending, 0);
    expect(repository.synced, 1);
    await tester.tap(find.text('Stop tracking'));
    await tester.pumpAndSettle();
    expect(bloc.state.tracking, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await bloc.close();
      await locations.controller.close();
      await connectivity.controller.close();
    });
  });
}
