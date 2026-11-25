import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:throw_app/core/atmosphere.dart';
import 'package:throw_app/core/preferences.dart';
import 'package:throw_app/core/theme.dart';
import 'package:throw_app/l10n/app_localizations.dart';
import 'package:throw_app/models/transfer_model.dart';
import 'package:throw_app/providers/device_provider.dart';
import 'package:throw_app/screens/discover_screen.dart';

import 'device_provider_test.dart' show RecordingService;

/// The narrowest phone this app supports, in logical pixels.
///
/// 360dp is not a hypothetical: it is the common Android width, and it is the
/// width at which the incoming-request row used to overflow.
const _narrow = 360.0;

Future<DeviceProvider> _pump(
  WidgetTester t, {
  required List<ConnectionRequest> requests,
  double width = _narrow,
}) async {
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  final service = RecordingService();
  final prefs = AppPreferences.inMemory();
  await prefs.setDeviceName('Test Phone');
  final provider = DeviceProvider(
    service: service,
    preferences: prefs,
    observeLifecycle: false,
  );
  for (final r in requests) {
    service.requestsController.add(r);
  }

  await t.pumpWidget(
    ChangeNotifierProvider<DeviceProvider>.value(
      value: provider,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThrowTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: DiscoverScreen()),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 400));
  return provider;
}

ConnectionRequest _req(String id, String name) => ConnectionRequest(
      endpointId: id,
      deviceName: name,
      receivedAt: DateTime(2026, 11, 26),
    );

void main() {
  setUp(() => Atmosphere.enabled = false);

  group('an incoming request fits on a narrow phone', () {
    testWidgets('nothing overflows at 360dp', (t) async {
      // The bug: both buttons lived in `FlatRow.trailing`, capped at 40% of the
      // window — 144dp at this width for two controls needing roughly 248. The
      // row overflowed by 104dp and pushed Accept off the right edge.
      final provider = await _pump(t, requests: [_req('p2p-a', 'Redmi 25080RABDC')]);
      addTearDown(provider.dispose);

      expect(t.takeException(), isNull,
          reason: 'no RenderFlex overflow is allowed on the narrowest phone');
    });

    testWidgets('the device name is actually rendered', (t) async {
      final provider = await _pump(t, requests: [_req('p2p-a', 'Redmi 25080RABDC')]);
      addTearDown(provider.dispose);

      // "no name nothing" — the row must say who is asking.
      expect(find.textContaining('Redmi 25080RABDC'), findsOneWidget);
    });

    testWidgets('the name is given room for two lines', (t) async {
      final provider = await _pump(
        t,
        requests: [_req('p2p-a', 'Mahim Mazidul Islam Mahim')],
      );
      addTearDown(provider.dispose);

      final text = t.widget<Text>(find.textContaining('Mahim').first);
      expect(text.maxLines, 2,
          reason: 'one line ellipsised a real name to "Mahim Ma..."');
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('both buttons are on screen and tappable', (t) async {
      final provider = await _pump(t, requests: [_req('p2p-a', 'Redmi')]);
      addTearDown(provider.dispose);

      for (final label in ['Reject', 'Accept']) {
        final finder = find.text(label);
        expect(finder, findsOneWidget, reason: '$label must be rendered');
        final box = t.getRect(finder);
        expect(box.left, greaterThanOrEqualTo(0.0),
            reason: '$label must not hang off the left edge');
        expect(box.right, lessThanOrEqualTo(_narrow),
            reason: '$label must not hang off the right edge');
      }
    });

    testWidgets('a nameless peer still gets a readable label', (t) async {
      // An endpoint that never announced a name: the row shows a short,
      // recognisable token rather than a blank or a raw UUID.
      final provider =
          await _pump(t, requests: [_req('p2p-a8:9c:ed:11:22', '')]);
      addTearDown(provider.dispose);

      expect(t.takeException(), isNull);
      expect(find.textContaining('Nearby device'), findsOneWidget);
    });

    testWidgets('several requests stack without overflow', (t) async {
      final provider = await _pump(t, requests: [
        _req('p2p-a', 'Redmi 25080RABDC'),
        _req('p2p-b8:9c:ed:44:55', ''),
      ]);
      addTearDown(provider.dispose);

      expect(t.takeException(), isNull);
      expect(find.text('Accept'), findsNWidgets(2));
      expect(find.text('Reject'), findsNWidgets(2));
    });
  });
}
