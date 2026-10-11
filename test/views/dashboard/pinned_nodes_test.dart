import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/views/dashboard/widget_registry.dart';
import 'package:fl_clash/views/dashboard/widgets/pinned_nodes.dart';
import 'package:fl_clash/views/dashboard/widgets/row_card.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

class _RecordingProxiesAction extends ProxiesAction {
  static final List<String> tested = [];

  @override
  Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
    tested.add(proxy.name);
  }
}

Group _nodes(List<String> names) => Group(
  type: GroupType.Selector,
  name: 'Nodes',
  hidden: false,
  all: [for (final name in names) Proxy(name: name, type: 'ss')],
);

void main() {
  late ProviderContainer container;

  setUp(() {
    _RecordingProxiesAction.tested.clear();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        proxiesActionProvider.overrideWith(_RecordingProxiesAction.new),
      ],
    );
    globalState.container = container;
    container.listen(groupsProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  void setNodes(List<String> names) {
    container.read(groupsProvider.notifier).value = [_nodes(names)];
  }

  void pin(List<String> names) {
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(pinnedProxies: names));
  }

  Future<void> pumpCard(WidgetTester tester, {double unitHeight = 80}) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: DashboardWidgetMetrics(
                  unitHeight: unitHeight,
                  child: const PinnedNodesCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: Scaffold(body: PinnedNodesSheet())),
      ),
    );
    await tester.pump();
  }

  test('is a four column widget the add button can offer', () {
    final item = DashboardWidget.pinnedNodes.widget;
    expect(item.crossAxisCellCount, 4);
    expect(item.child, isA<PinnedNodesCard>());
    expect(dashboardWidgetOf(item), DashboardWidget.pinnedNodes);
    expect(
      defaultDashboardWidgets,
      isNot(contains(DashboardWidget.pinnedNodes)),
    );
  });

  test('pinned names keep their order and drop the ones no group has', () {
    final nodes = pinnedNodesIn(
      [
        _nodes(['HK-01', 'JP-01']),
      ],
      ['JP-01', 'GONE', 'HK-01'],
    );

    expect(nodes.map((node) => node.proxy.name), ['JP-01', 'HK-01']);
  });

  testWidgets('an unpinned card offers the picker instead of a blank body', (
    tester,
  ) async {
    setNodes(['HK-01']);
    await pumpCard(tester);

    expect(find.byType(RowCardEmpty), findsOneWidget);
    expect(find.byType(EmptyIllustration), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pin nodes'), findsOneWidget);
  });

  testWidgets('the card reads out the pinned nodes and their latency', (
    tester,
  ) async {
    setNodes(['HK-01', 'JP-01', 'US-01']);
    pin(['US-01', 'HK-01']);
    container
        .read(delayDataSourceProvider.notifier)
        .setDelay(const Delay(name: 'US-01', url: defaultTestUrl, value: 123));
    await pumpCard(tester, unitHeight: 120);

    final pills = find.byType(RowCardPill);
    expect(pills, findsNWidgets(2));
    expect(
      find.descendant(
        of: pills.first,
        matching: find.text('US-01', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(find.text('123 ms'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    // A delay ends the loading throttle, whose timer outlives the tree.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a card row tests the latency of its own node', (tester) async {
    setNodes(['HK-01', 'JP-01']);
    pin(['JP-01']);
    await pumpCard(tester);

    await tester.tap(find.byType(RowCardPill).first);
    await tester.pump();

    expect(_RecordingProxiesAction.tested, ['JP-01']);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the sheet lists the group nodes and pins the tapped one', (
    tester,
  ) async {
    setNodes(['HK-01', 'JP-01']);
    await pumpSheet(tester);

    expect(find.byType(DecorationListItem), findsNWidgets(2));

    await tester.tap(find.text('HK-01', findRichText: true));
    await tester.pump();
    expect(container.read(appSettingProvider).pinnedProxies, ['HK-01']);

    await tester.tap(find.text('HK-01', findRichText: true));
    await tester.pump();
    expect(container.read(appSettingProvider).pinnedProxies, isEmpty);
  });

  testWidgets('the sheet tests a node delay from its own row', (tester) async {
    setNodes(['HK-01', 'JP-01']);
    await pumpSheet(tester);

    await tester.tap(find.byTooltip('Delay test').first);
    await tester.pump();

    expect(_RecordingProxiesAction.tested, ['HK-01']);
  });
}
