import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'tracking_bloc.dart';
import 'tracksync_logo.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});
  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<TrackingBloc>().add(RefreshConnection());
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TrackingBloc, TrackingState>(builder: (context, state) {
        final bloc = context.read<TrackingBloc>();
        final latest = state.snapshot.recent.firstOrNull;
        return Scaffold(
          appBar: AppBar(
              title: const Row(children: [
                TrackSyncLogo(size: 36),
                SizedBox(width: 10),
                Text('TrackSync',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, letterSpacing: -.8))
              ]),
              actions: [
                IconButton(
                    tooltip: 'About background tracking',
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                                title: const Text('Built for the demo'),
                                content: const Text(
                                    'This app simulates a location every 3 seconds while running. '
                                    'It does not run a background GPS service. The OS may suspend updates when minimized or locked. '
                                    'Saved points survive restarts and sync when you reopen the app. '
                                    'The README explains Android foreground services and iOS background location.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Got it'))
                                ])),
                    icon: const Icon(Icons.info_outline)),
                const SizedBox(width: 8)
              ]),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            const Text('DRIVER WORKSPACE',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                    color: Color(0xFF64748B))),
                            const SizedBox(height: 8),
                            const Text('Every stop. In sync.',
                                style: TextStyle(
                                    fontSize: 30,
                                    height: 1.1,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1)),
                            const SizedBox(height: 8),
                            const Text(
                                'Keep your journey moving, even when the network doesn’t.',
                                style: TextStyle(color: Color(0xFF64748B))),
                            const SizedBox(height: 24),
                            Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF102F31),
                                    borderRadius: BorderRadius.circular(24)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Icon(
                                            state.tracking
                                                ? Icons.radio_button_checked
                                                : Icons.pause_circle_outline,
                                            color: const Color(0xFFC9F477),
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                            state.tracking
                                                ? 'TRACKING ACTIVE'
                                                : 'READY WHEN YOU ARE',
                                            style: const TextStyle(
                                                color: Color(0xFFC9F477),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2))
                                      ]),
                                      const SizedBox(height: 20),
                                      Text(
                                          latest == null
                                              ? 'Your journey starts here'
                                              : '${latest.latitude.toStringAsFixed(5)}° N',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 25,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(
                                          latest == null
                                              ? 'Start a simulated route around Bengaluru.'
                                              : '${latest.longitude.toStringAsFixed(5)}° E · Bengaluru demo route',
                                          style: const TextStyle(
                                              color: Color(0xFFB4CDCB))),
                                      const SizedBox(height: 22),
                                      SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                              style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFFC9F477),
                                                  foregroundColor:
                                                      const Color(0xFF102F31),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          vertical: 16)),
                                              onPressed: state.ready
                                                  ? () =>
                                                      bloc.add(ToggleTracking())
                                                  : null,
                                              icon: Icon(state.tracking
                                                  ? Icons.stop_rounded
                                                  : Icons.near_me_outlined),
                                              label: Text(
                                                  state.tracking
                                                      ? 'Stop tracking'
                                                      : 'Start tracking',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)))),
                                      const SizedBox(height: 10),
                                      const Center(
                                          child: Text(
                                              'SIMULATED GPS · EVERY 3 SECONDS',
                                              style: TextStyle(
                                                  color: Color(0xFFB4CDCB),
                                                  fontSize: 10,
                                                  letterSpacing: 1))),
                                    ])),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(
                                  child: _Metric(
                                      value: '${state.snapshot.pending}',
                                      label: 'Saved on device',
                                      icon: Icons.cloud_upload_outlined)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _Metric(
                                      value: '${state.snapshot.synced}',
                                      label: 'Synced to mock API',
                                      icon: Icons.cloud_done_outlined))
                            ]),
                            const SizedBox(height: 20),
                            Card(
                                margin: EdgeInsets.zero,
                                color: Colors.white,
                                elevation: 0,
                                child: Column(children: [
                                  ListTile(
                                      leading: Icon(
                                          state.canSync
                                              ? Icons.wifi
                                              : Icons.wifi_off,
                                          color: const Color(0xFF087F70)),
                                      title: Text(state.syncing
                                          ? 'Synchronizing…'
                                          : state.canSync
                                              ? 'Connection available'
                                              : 'Offline · saving locally'),
                                      subtitle:
                                          const Text('In-app mock REST API'),
                                      trailing: IconButton(
                                          tooltip: 'Sync now',
                                          onPressed: state.canSync &&
                                                  !state.syncing &&
                                                  state.snapshot.pending > 0
                                              ? () => bloc.add(RetrySync())
                                              : null,
                                          icon: const Icon(Icons.sync))),
                                  const Divider(height: 1),
                                  SwitchListTile(
                                      title: const Text('Simulate offline'),
                                      subtitle: const Text(
                                          'Turn off to automatically upload saved points'),
                                      value: state.forcedOffline,
                                      onChanged: state.ready
                                          ? (value) =>
                                              bloc.add(SetOffline(value))
                                          : null),
                                ])),
                            if (state.error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(state.error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            const SizedBox(height: 24),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Recent locations',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700)),
                                  Text('LATEST ${state.snapshot.recent.length}',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          letterSpacing: 1,
                                          color: Color(0xFF64748B)))
                                ]),
                            const SizedBox(height: 10),
                            if (state.snapshot.recent.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                      'No locations yet. Start tracking to record your first point.',
                                      textAlign: TextAlign.center,
                                      style:
                                          TextStyle(color: Color(0xFF64748B)))),
                            ...state.snapshot.recent.map((point) => Card(
                                elevation: 0,
                                color: Colors.white,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(
                                      point.synced
                                          ? Icons.check_circle_outline
                                          : Icons.schedule,
                                      color: point.synced
                                          ? const Color(0xFF087F70)
                                          : const Color(0xFF9A6700)),
                                  title: Text(
                                      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                      '${TimeOfDay.fromDateTime(point.recordedAt.toLocal()).format(context)} · ${point.id.substring(0, 8)}'),
                                  trailing: Text(
                                      point.synced ? 'Synced' : 'Pending',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: point.synced
                                              ? const Color(0xFF087F70)
                                              : const Color(0xFF9A6700))),
                                ))),
                            const SizedBox(height: 12),
                            const Text(
                                'Foreground simulation only. Background GPS design is documented in the README.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 12),
                          ])))),
        );
      });
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, required this.icon});
  final String value, label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: const Color(0xFF087F70), size: 22),
        const SizedBox(height: 12),
        Text(value,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))
      ]));
}
