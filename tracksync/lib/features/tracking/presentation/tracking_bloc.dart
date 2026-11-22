import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/location_point.dart';
import '../domain/tracking_repository.dart';

sealed class TrackingEvent {}

class InitializeTracking extends TrackingEvent {}

class ToggleTracking extends TrackingEvent {}

class SetOffline extends TrackingEvent {
  SetOffline(this.value);
  final bool value;
}

class RetrySync extends TrackingEvent {}

class RefreshConnection extends TrackingEvent {}

class _ConnectionChanged extends TrackingEvent {
  _ConnectionChanged(this.online);
  final bool online;
}

class _PointReceived extends TrackingEvent {
  _PointReceived(this.point);
  final LocationPoint point;
}

class _SourceFailed extends TrackingEvent {}

class TrackingState {
  const TrackingState(
      {this.ready = false,
      this.tracking = false,
      this.online = false,
      this.forcedOffline = false,
      this.syncing = false,
      this.snapshot = const TrackingSnapshot(),
      this.error});
  final bool ready, tracking, online, forcedOffline, syncing;
  final TrackingSnapshot snapshot;
  final String? error;
  bool get canSync => online && !forcedOffline;
  TrackingState copyWith(
          {bool? ready,
          bool? tracking,
          bool? online,
          bool? forcedOffline,
          bool? syncing,
          TrackingSnapshot? snapshot,
          String? error}) =>
      TrackingState(
          ready: ready ?? this.ready,
          tracking: tracking ?? this.tracking,
          online: online ?? this.online,
          forcedOffline: forcedOffline ?? this.forcedOffline,
          syncing: syncing ?? this.syncing,
          snapshot: snapshot ?? this.snapshot,
          error: error);
}

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  TrackingBloc(this.repository, this.locations, this.connectivity)
      : super(const TrackingState()) {
    // A single sequential event pipeline serializes storage, controls and sync.
    on<TrackingEvent>(_handle,
        transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final TrackingRepository repository;
  final LocationSource locations;
  final ConnectivitySource connectivity;
  StreamSubscription<LocationPoint>? _positions;
  StreamSubscription<bool>? _connection;
  Timer? _retry;
  int _failures = 0;

  Future<void> _handle(TrackingEvent event, Emitter<TrackingState> emit) async {
    try {
      if (event is InitializeTracking) {
        _connection ??= connectivity.changes.listen(
            (online) => add(_ConnectionChanged(online)),
            onError: (Object _) => add(_ConnectionChanged(false)));
        emit(state.copyWith(
            ready: true,
            snapshot: await repository.snapshot(),
            online: await connectivity.isOnline));
        add(RetrySync());
      } else if (event is ToggleTracking) {
        if (!state.ready) return;
        if (state.tracking) {
          emit(state.copyWith(tracking: false));
          await _positions?.cancel();
          _positions = null;
        } else {
          emit(state.copyWith(tracking: true));
          _positions = locations.positions().listen(
              (point) => add(_PointReceived(point)),
              onError: (Object _) => add(_SourceFailed()));
        }
      } else if (event is _PointReceived) {
        if (!state.tracking) return;
        await repository.save(event.point);
        emit(state.copyWith(
            snapshot: await repository.snapshot(), error: state.error));
        if (_retry == null) add(RetrySync());
      } else if (event is SetOffline) {
        emit(state.copyWith(forcedOffline: event.value));
        _retry?.cancel();
        _retry = null;
        if (!event.value) add(RetrySync());
      } else if (event is RefreshConnection) {
        add(_ConnectionChanged(await connectivity.isOnline));
      } else if (event is _ConnectionChanged) {
        emit(state.copyWith(online: event.online));
        if (event.online) {
          _retry?.cancel();
          _retry = null;
          add(RetrySync());
        }
      } else if (event is _SourceFailed) {
        await _positions?.cancel();
        _positions = null;
        emit(state.copyWith(
            tracking: false,
            error: 'Location simulator stopped. Start tracking to retry.'));
      } else if (event is RetrySync) {
        if (!state.ready || !state.canSync || state.snapshot.pending == 0) {
          return;
        }
        _retry?.cancel();
        _retry = null;
        emit(state.copyWith(syncing: true));
        try {
          await repository.synchronize();
          _failures = 0;
          emit(state.copyWith(
              syncing: false, snapshot: await repository.snapshot()));
          if (state.snapshot.pending > 0) add(RetrySync());
        } catch (_) {
          _failures++;
          final seconds = min(60, 2 * pow(2, min(_failures - 1, 5)).toInt());
          emit(state.copyWith(
              syncing: false,
              snapshot: await repository.snapshot(),
              error:
                  'Upload failed. Saved on device. Retrying in ${seconds}s.'));
          _retry = Timer(Duration(seconds: seconds), () {
            _retry = null;
            add(RetrySync());
          });
        }
      }
    } catch (_) {
      await _positions?.cancel();
      _positions = null;
      emit(state.copyWith(
          tracking: false,
          syncing: false,
          error:
              'Unable to access local data or device services. Reopen the app to retry.'));
    }
  }

  @override
  Future<void> close() async {
    _retry?.cancel();
    await _positions?.cancel();
    await _connection?.cancel();
    await super.close();
    _retry?.cancel();
  }
}
