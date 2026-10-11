import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/views/dashboard/widget_registry.dart';
import 'package:fl_clash/views/dashboard/widgets/pinned_nodes.dart';
import 'package:fl_clash/views/proxies/card.dart';
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

  testWidgets('shows an empty state without nodes', (tester) async {
    await pumpCard(tester);

    expect(find.byType(EmptyIllustration), findsOneWidget);
  });

  testWidgets('draws the proxies page cards with pin and delay controls', (
    tester,
  ) async {
    setNodes(['HK-01', 'JP-01']);
    await pumpCard(tester);

    expect(find.byType(ProxyCard), findsNWidgets(2));
    expect(find.text('HK-01', findRichText: true), findsOneWidget);
    expect(find.byTooltip('Pin'), findsNWidgets(2));
    expect(find.byTooltip('Delay test'), findsNWidgets(2));
  });

  testWidgets('shows the latency a node already has', (tester) async {
    setNodes(['HK-01']);
    container
        .read(delayDataSourceProvider.notifier)
        .setDelay(const Delay(name: 'HK-01', url: defaultTestUrl, value: 123));
    await pumpCard(tester);

    expect(find.text('123 ms'), findsOneWidget);
  });

  testWidgets('a delay tap tests the node of that card', (tester) async {
    setNodes(['HK-01', 'JP-01']);
    await pumpCard(tester);

    await tester.tap(find.byTooltip('Delay test').first);
    await tester.pump();

    expect(_RecordingProxiesAction.tested, ['HK-01']);
  });

  testWidgets('a card tap pins the node and it leads the list', (tester) async {
    setNodes(['HK-01', 'JP-01', 'US-01']);
    await pumpCard(tester, unitHeight: 120);

    await tester.tap(find.byType(ProxyCard).at(2));
    await tester.pumpAndSettle();

    expect(container.read(appSettingProvider).pinnedProxies, ['US-01']);
    expect(find.byTooltip('Unpin'), findsOneWidget);
    expect(
      tester.widget<ProxyCard>(find.byType(ProxyCard).first).proxy.name,
      'US-01',
    );
  });

  testWidgets('a card tap unpins the node again', (tester) async {
    setNodes(['HK-01', 'JP-01']);
    await pumpCard(tester);

    await tester.tap(find.byType(ProxyCard).first);
    await tester.pumpAndSettle();
    expect(container.read(appSettingProvider).pinnedProxies, ['HK-01']);

    await tester.tap(find.byType(ProxyCard).first);
    await tester.pumpAndSettle();
    expect(container.read(appSettingProvider).pinnedProxies, isEmpty);
  });
}
