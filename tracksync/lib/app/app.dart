import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import '../features/tracking/data/device_sources.dart';
import '../features/tracking/data/location_api.dart';
import '../features/tracking/data/location_store.dart';
import '../features/tracking/data/offline_tracking_repository.dart';
import '../features/tracking/presentation/tracking_bloc.dart';
import '../features/tracking/presentation/tracking_page.dart';

class TrackSyncApp extends StatefulWidget {
  const TrackSyncApp({super.key});
  @override
  State<TrackSyncApp> createState() => _TrackSyncAppState();
}

class _TrackSyncAppState extends State<TrackSyncApp> {
  late Future<LocationStore> _store = LocationStore.open();
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TrackSync',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF087F70)),
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFF5F7FA), centerTitle: false)),
        home: FutureBuilder<LocationStore>(
            future: _store,
            builder: (context, result) {
              if (result.hasError) {
                return Scaffold(
                    body: Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Could not open local storage.'),
                  TextButton(
                      onPressed: () =>
                          setState(() => _store = LocationStore.open()),
                      child: const Text('Try again')),
                ])));
              }
              if (!result.hasData) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              final store = result.requireData;
              return BlocProvider(
                  create: (_) => TrackingBloc(
                      OfflineTrackingRepository(
                          store,
                          LocationApi(
                              mockLocationClient(store.database),
                              Uri.parse(
                                  'https://mock.tracksync.local/locations'))),
                      SimulatedLocationSource(),
                      DeviceConnectivity())
                    ..add(InitializeTracking()),
                  child: const TrackingPage());
            }),
      );
}
