import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:fl_clash/views/proxies/proxies.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

const _groupName = 'Selector';

Group _group() => Group(
  name: _groupName,
  type: GroupType.Selector,
  hidden: false,
  now: 'Proxy 0',
  all: [
    for (var index = 0; index < 6; index++)
      Proxy(name: 'Proxy $index', type: 'Direct'),
  ],
);

Profile _profile() => Profile.normal().copyWith(
  currentGroupName: _groupName,
  selectedMap: {_groupName: 'Proxy 0'},
  unfoldSet: {_groupName},
);

ProviderContainer _container(
  Profile profile,
  Group group, {
  List<String> pinnedProxies = const [],
}) {
  return ProviderContainer(
    overrides: [
      profilesProvider.overrideWith(() => TestProfiles([profile])),
      currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
      currentGroupsStateProvider.overrideWithValue(GroupsState(value: [group])),
      groupsProvider.overrideWithValue([group]),
      appSettingProvider.overrideWithBuild(
        (_, _) => AppSettingProps(pinnedProxies: pinnedProxies),
      ),
    ],
  );
}

void main() {
  test('a pinned node leads the list, in the order it was pinned', () {
    final container = _container(
      _profile(),
      _group(),
      pinnedProxies: ['Proxy 4', 'Proxy 1'],
    );
    addTearDown(container.dispose);

    final names = container
        .read(proxiesTabStateProvider)
        .groups
        .single
        .all
        .map((proxy) => proxy.name)
        .toList();
    expect(names.take(2), ['Proxy 4', 'Proxy 1']);
    expect(names.length, 6);
    expect(names.toSet(), _group().all.map((proxy) => proxy.name).toSet());
  });

  test('a search keeps the pinned nodes in front', () {
    final container = _container(
      _profile(),
      _group(),
      pinnedProxies: ['Proxy 4'],
    );
    addTearDown(container.dispose);

    final names = container
        .read(filterGroupsStateProvider('Proxy'))
        .value
        .single
        .all
        .map((proxy) => proxy.name)
        .toList();
    expect(names.first, 'Proxy 4');
    expect(names.length, 6);
  });

  testWidgets(
    'the pin button pins the nodes tapped and saves on the second tap',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final profile = _profile();
      final group = _group();
      final container = _container(profile, group);
      addTearDown(container.dispose);
      globalState.container = container;
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(1200, 900));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: ProxiesView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Pin nodes'), findsOneWidget);
      expect(find.byTooltip('Pin'), findsNothing);

      await tester.tap(find.byTooltip('Pin nodes'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Save'), findsOneWidget);
      expect(find.byTooltip('Pin'), findsNWidgets(6));

      await tester.tap(find.byType(ProxyCard).at(3));
      await tester.pumpAndSettle();

      expect(container.read(appSettingProvider).pinnedProxies, ['Proxy 3']);
      expect(find.byTooltip('Unpin'), findsOneWidget);
      expect(
        tester.widget<ProxyCard>(find.byType(ProxyCard).first).proxy.name,
        'Proxy 3',
      );

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Pin nodes'), findsOneWidget);
      expect(find.byTooltip('Pin'), findsNothing);
      expect(
        tester.widget<ProxyCard>(find.byType(ProxyCard).first).proxy.name,
        'Proxy 3',
      );

      await tester.tap(find.byTooltip('Pin nodes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ProxyCard).first);
      await tester.pumpAndSettle();

      expect(container.read(appSettingProvider).pinnedProxies, isEmpty);
    },
  );

  testWidgets('the list layout pins nodes the same way', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final profile = _profile();
    final group = _group();
    final container = _container(profile, group);
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1200, 900));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ProxiesView()),
      ),
    );
    container
        .read(proxiesStyleSettingProvider.notifier)
        .update((state) => state.copyWith(type: ProxiesType.list));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pin nodes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ProxyCard).at(2));
    await tester.pumpAndSettle();

    expect(container.read(appSettingProvider).pinnedProxies, ['Proxy 2']);
    expect(
      tester.widget<ProxyCard>(find.byType(ProxyCard).first).proxy.name,
      'Proxy 2',
    );
  });
}
