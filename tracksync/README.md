# TrackSync

<img src="assets/branding/tracksync.png" alt="TrackSync logo" width="80" />

A focused Flutter assessment: simulated driver locations, a durable SQLite outbox,
automatic synchronization, and BLoC state management. No API keys or GPS permission needed.

## Run

Built with Flutter 3.50.1 / Dart 3.14. Use a Flutter SDK with Dart 3.14 or newer.
Android and iOS are supported; web/desktop runners are not included.

```sh
flutter pub get
flutter run
```

For Android, configure your SDK in the ignored `android/local.properties`:

```properties
flutter.sdk=/absolute/path/to/flutter
sdk.dir=/absolute/path/to/Android/sdk
```

For iOS, install Xcode and its simulator runtime. Select an available simulator with
`flutter devices` and run `flutter run -d <device-id>`. A physical device requires
selecting your own signing team in Xcode. Android release signing currently uses
the template debug key; configure your own upload key before publishing.

## Demonstrate (about one minute)

1. Start tracking. A simulated Bengaluru route produces a point immediately, then every 3 seconds.
2. Enable **Simulate offline**. Watch pending locations accumulate.
3. Stop tracking, close and reopen the app with the device offline: the pending queue survives.
4. Restore device connectivity / turn off **Simulate offline**. Pending points synchronize automatically.
5. Tap **Sync now** repeatedly: acknowledged records are not uploaded again.

The offline switch is session-only and defaults to off after a restart. Use airplane
mode to keep the queue offline across restarts. Start/stop applies to collection;
previously saved points continue synchronizing even after tracking stops.

[Watch the recorded Android demo](docs/tracksync-demo.mp4) (26 seconds): start tracking,
simulate offline, accumulate points, stop, then restore connectivity and synchronize.
The recording starts with existing demo history; counters are cumulative.

To record another walkthrough, use the emulator screen recorder or iOS Simulator's
**File → Record Screen**.

## Architecture

```text
lib/
  main.dart                         Flutter entry point only
  app/app.dart                      Dependency composition and theme
  features/tracking/
    domain/                         Plain Dart entities and repository/source contracts
    data/                           SQLite, REST adapter, mock transport, device sources
    presentation/                   BLoC events/state, screen, vector logo
assets/branding/tracksync.svg        Reusable TrackSync route mark
```

The domain has no Flutter/plugin dependency. Presentation depends on domain
contracts; infrastructure is injected at the composition root. The repository
encapsulates the save and synchronize operations directly rather than adding
pass-through use-case classes for this small assessment.

BLoC handles all event types through one sequential pipeline. That prevents a
stop/start, connection event, or upload from racing another state transition.
SQLite writes complete before upload is attempted. A repository-level single-flight
future also coalesces simultaneous sync calls. A batch processes at most 100 points;
remaining batches are scheduled automatically. The list shows the latest 20 points.

## REST mock and duplicate prevention

The default API is an **in-process `http.MockClient`**, not a hosted endpoint. It
handles `POST https://mock.tracksync.local/locations`; no DNS request is made.
The app uses real JSON request/response handling, status checks and a 10-second timeout.

```json
{"id":"stable-uuid","latitude":12.9716,"longitude":77.5946,"recordedAt":"2026-01-01T00:00:00.000Z"}
```

Request header: `Idempotency-Key: <id>`.
Success (200/201): `{"id":"stable-uuid","accepted":true}`.

Every point receives a UUID once, before being written to SQLite. The local primary
key rejects duplicate inserts. The mock's separate `mock_receipts` table has a unique
ID and persists receipts, emulating an idempotent server. Only a matching successful
acknowledgment marks the outbox row synced. If the server accepts a point but its
response is lost, retrying the same ID returns success without another receipt.
This is **at-least-once delivery with idempotent acceptance**, not a claim of exactly-once transport.

To use a real REST service, inject `http.Client()` and its HTTPS endpoint into
`LocationApi` in `app.dart`. The server must atomically enforce uniqueness of the
location ID and return the same acknowledgment for repeats; client logic alone
cannot guarantee server-side deduplication. Mock receipts live on this device only
and do not establish cross-device/server behavior. Add Android INTERNET permission
when switching to a network transport.

`connectivity_plus` reports network availability, not internet reachability. Failed
HTTP calls remain queued and retry after 2, 4, 8, 16, 32, then 60 seconds (capped).
New points do not bypass the retry delay. Reconnection, app resume, or manual sync
can trigger an immediate attempt. Retries continue while the app is running;
a queued point is never discarded on a network error. Permanent HTTP failures also
remain queued; production would classify errors and quarantine invalid records.

## Background tracking: deliberate scope

**This implementation is a foreground simulator.** A Dart timer/stream does not
provide reliable updates when minimized, locked, suspended or terminated. It may
continue briefly on some devices; that is not a supported guarantee. On resume,
connectivity is checked and the durable queue is drained. Tracking starts stopped
after a cold launch. No fabricated points are backfilled for suspended time.

For real GPS:

- **Android:** replace `LocationSource` with native fused-location updates owned by
  a location foreground service started while the app is visible. Declare its
  location service type, foreground service permissions (including
  `FOREGROUND_SERVICE_LOCATION` where required), request runtime coarse/fine location,
  and show an ongoing notification with a stop action. Background service starts
  are restricted; background location permission is needed for applicable background
  access/start scenarios, not requested indiscriminately. Persist each callback in
  SQLite independently of the screen. WorkManager can drain the queue with network
  constraints, but is not a continuous GPS timer. Respect force-stop and battery limits.
- **iOS:** use Core Location, purpose strings and appropriate user authorization;
  enable the Location updates background capability (`UIBackgroundModes: location`)
  and configure background updates on the location manager. Request Always access
  only where the chosen delivery mode requires it. Write received updates immediately.
  Suspension, termination, force-quit and power policy affect delivery; do not promise
  uninterrupted sampling. Background task scheduling is opportunistic, not a 3-second timer.

References: [Android location foreground services](https://developer.android.com/develop/background-work/services/fgs/service-types#location),
[background start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start),
[Apple background location](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background),
[allowsBackgroundLocationUpdates](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates).

## Tests

```sh
flutter analyze
flutter test
```

Tests use SQLite FFI for actual database persistence, plus controlled HTTP responses:
restart durability, duplicate insertion, retry preservation, lost acknowledgment,
single-flight synchronization, wrong acknowledgment, partial batch failure, and a
widget/BLoC start–offline–reconnect–stop flow.

## Verification

- `flutter analyze`: no issues.
- `flutter test`: all 8 tests passed.
- Android debug APK built and launched on the Android 17 emulator.
- Recorded offline accumulation and automatic synchronization; visually checked the recording.
- iOS configuration and icons are included; an iOS build/device run was not verified.

## Assessment tradeoffs

No authentication, real GPS, native background service, map tiles or hosted backend.
Synced history and mock receipts are retained indefinitely for demonstration; add
retention, encryption as appropriate, consent/privacy handling, batch uploads,
retry jitter and operational logging for a production system. A slow batch delays
BLoC controls until it finishes; production should isolate synchronization from
collection with transactional queue coordination. SQLite initialization failures
show a retry screen; storage failures stop collection and display an error.

The original logo is drawn as a vector in Flutter and included as SVG; no image
runtime or external font dependency is required. Publishing to GitHub is left to
the repository owner.
