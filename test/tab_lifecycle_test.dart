import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/widgets/swipeable_tabs.dart';

/// A screen that counts how many times it is created.
///
/// The count is the whole assertion. Creating a tab's state is only allowed to
/// happen once, at mount — if a swipe makes it happen again, the tab lost
/// everything it was holding.
class _Probe extends StatefulWidget {
  const _Probe({required this.id, required this.log});
  final String id;
  final Map<String, int> log;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  late final int _serial;

  @override
  void initState() {
    super.initState();
    _serial = (widget.log[widget.id] ?? 0) + 1;
    widget.log[widget.id] = _serial;
  }

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('${widget.id}#$_serial'));
}

void main() {
  testWidgets('a tab is created once and never rebuilt by a swipe', (t) async {
    final log = <String, int>{};
    var index = 0;
    late StateSetter setIndex;

    await t.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setIndex = setState;
            return Scaffold(
              body: SwipeableTabs(
                index: index,
                onChanged: (i) => setIndex(() => index = i),
                children: [
                  _Probe(id: 'Home', log: log),
                  _Probe(id: 'Discover', log: log),
                  _Probe(id: 'Transfers', log: log),
                  _Probe(id: 'Settings', log: log),
                ],
              ),
            );
          },
        ),
      ),
    );

    expect(log.values, everyElement(1), reason: 'every tab mounts once');

    // Walk the whole tab strip, including backwards, so both the direction
    // branches and the replay-from-either-end paths are covered.
    for (final target in [1, 2, 3, 2, 1, 0]) {
      setIndex(() => index = target);
      await t.pumpAndSettle();
      expect(
        log.values,
        everyElement(1),
        reason: 'moving to tab $target must not recreate any tab',
      );
    }
  });

  testWidgets('a swipe keeps the tab alive, with its state intact', (t) async {
    final log = <String, int>{};
    var index = 0;
    late StateSetter setIndex;

    await t.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setIndex = setState;
            return Scaffold(
              body: SwipeableTabs(
                index: index,
                onChanged: (i) => setIndex(() => index = i),
                children: [
                  _Probe(id: 'Home', log: log),
                  _Probe(id: 'Discover', log: log),
                ],
              ),
            );
          },
        ),
      ),
    );

    setIndex(() => index = 1);
    await t.pumpAndSettle();

    // The serial is baked into the rendered text, so a rebuilt tab would show
    // a higher number even if the map somehow stayed clean.
    expect(find.text('Home#1'), findsNothing,
        reason: 'Home is off stage after moving away');
    expect(find.text('Discover#1'), findsOneWidget);

    setIndex(() => index = 0);
    await t.pumpAndSettle();
    expect(find.text('Home#1'), findsOneWidget,
        reason: 'Home comes back as the same instance, not a fresh one');
  });
}
