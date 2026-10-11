import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'row_card.dart';

/// Shows the nodes pinned on the proxies page and hands the dashboard a sheet
/// for changing them, so the card stays a dashboard readout of what is pinned
/// instead of a second copy of the proxies page.
class PinnedNodesCard extends ConsumerStatefulWidget {
  const PinnedNodesCard({super.key});

  @override
  ConsumerState<PinnedNodesCard> createState() => _PinnedNodesCardState();
}

class _PinnedNodesCardState extends ConsumerState<PinnedNodesCard> {
  final _controller = RowSnapScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final nodes = pinnedNodesIn(
      ref.watch(visibleGroupsStateProvider).value,
      ref.watch(appSettingProvider.select((state) => state.pinnedProxies)),
    );
    return RowCardFrame(
      child: RowCardPane(
        header: InfoHeader(
          // InfoHeader takes its own 8 back off a header that carries actions,
          // so the bottom margin asks for exactly that much and no more.
          padding: DashboardWidgetMetrics.paddingOf(
            context,
          ).copyWith(bottom: 8.mAp),
          info: Info(label: appLocalizations.pinNodes, glyph: AppGlyphs.pin),
          actions: [
            SizedBox.square(
              dimension: 28,
              child: IconButton(
                tooltip: appLocalizations.edit,
                padding: EdgeInsets.zero,
                onPressed: () => showPinnedNodesSheet(context),
                icon: const GlyphIcon(AppGlyphs.sliders),
              ),
            ),
          ],
        ),
        body: nodes.isEmpty
            ? RowCardEmpty(
                illustration: NullStatusIllustration.proxies,
                action: CommonMinFilledButtonTheme(
                  child: FilledButton.tonalIcon(
                    onPressed: () => showPinnedNodesSheet(context),
                    icon: const GlyphIcon(AppGlyphs.pin, fill: 1),
                    label: Text(appLocalizations.pinNodes),
                  ),
                ),
              )
            : RowCardSlots(
                rowExtent: rowCardLineExtentOf(context),
                builder: (_, rowHeight, spacing) {
                  final extent = rowHeight + spacing;
                  _controller.itemExtent = extent;
                  return ListView.builder(
                    controller: _controller,
                    padding: EdgeInsets.zero,
                    physics: const RowSnapScrollPhysics(),
                    itemExtent: extent,
                    itemCount: nodes.length,
                    itemBuilder: (_, index) {
                      final node = nodes[index];
                      return Padding(
                        padding: EdgeInsets.only(bottom: spacing),
                        child: RowCardPill(
                          onTap: () => testPinnedDelay(ref, node),
                          child: Row(
                            spacing: 8,
                            children: [
                              Expanded(
                                child: OverflowTooltipText(
                                  text: node.proxy.name,
                                  style: context.textTheme.bodyMedium,
                                ),
                              ),
                              _NodeDelay(node: node),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

/// Lists the nodes of the group the proxies page shows and toggles the pin of
/// the row that is tapped, so pinning is one deliberate tap in a list that
/// says which rows are pinned.
class PinnedNodesSheet extends ConsumerWidget {
  const PinnedNodesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final groups = ref.watch(visibleGroupsStateProvider).value;
    final group = currentGroupIn(
      groups,
      ref.watch(
        proxiesTabStateProvider.select((state) => state.currentGroupName),
      ),
    );
    final proxies = group?.all ?? const <Proxy>[];
    final pinned = ref.watch(
      appSettingProvider.select((state) => state.pinnedProxies),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: ref.sheetHeight(context, 0.7)),
      child: CommonScaffold(
        title: appLocalizations.pinNodes,
        body: CustomScrollView(
          shrinkWrap: true,
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: context.contentTopPadding),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.builder(
                itemCount: proxies.length,
                itemBuilder: (context, index) {
                  final proxy = proxies[index];
                  final node = group == null
                      ? null
                      : PinnedNode(group: group, proxy: proxy);
                  return ItemPositionProvider(
                    position: ItemPosition.get(index, proxies.length),
                    child: DecorationListItem(
                      isSelected: pinned.contains(proxy.name),
                      minVerticalPadding: 10,
                      onPressed: () => togglePinnedProxy(ref, proxy.name),
                      leading: GlyphIcon(
                        AppGlyphs.pin,
                        fill: pinned.contains(proxy.name) ? 1 : 0,
                      ),
                      title: EmojiText(
                        proxy.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: [
                          if (node != null) _NodeDelay(node: node),
                          IconButton(
                            tooltip: appLocalizations.delayTest,
                            onPressed: node == null
                                ? null
                                : () => testPinnedDelay(ref, node),
                            icon: const GlyphIcon(AppGlyphs.bolt),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPinnedNodesSheet(BuildContext context) {
  return showSheet(
    context: context,
    props: nestedPagedSheetProps,
    builder: (_) => NestedPagedSheet(builder: (_) => const PinnedNodesSheet()),
  );
}

/// A pinned node together with the group it was found in, which is where its
/// test URL comes from.
class PinnedNode {
  const PinnedNode({required this.group, required this.proxy});

  final Group group;
  final Proxy proxy;
}

/// The nodes named in the pinned setting, in pin order, resolved against the
/// groups the proxies page shows. A name no group carries is skipped, which is
/// how a pinned node leaves with the subscription it came from.
List<PinnedNode> pinnedNodesIn(List<Group> groups, List<String> names) {
  final nodes = <PinnedNode>[];
  for (final name in names) {
    for (final group in groups) {
      final index = group.all.indexWhere((proxy) => proxy.name == name);
      if (index < 0) {
        continue;
      }
      nodes.add(PinnedNode(group: group, proxy: group.all[index]));
      break;
    }
  }
  return nodes;
}

Group? currentGroupIn(List<Group> groups, String? groupName) {
  return groups.getGroup(groupName ?? '') ??
      (groups.isEmpty ? null : groups.first);
}

void testPinnedDelay(WidgetRef ref, PinnedNode node) {
  ref
      .read(proxiesActionProvider.notifier)
      .proxyDelayTest(node.proxy, node.group.testUrl);
}

class _NodeDelay extends ConsumerWidget {
  const _NodeDelay({required this.node});

  final PinnedNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = ref.watch(
      delayProvider(proxyName: node.proxy.name, testUrl: node.group.testUrl),
    );
    final phase = ref.watch(
      delayTestPhaseProvider(
        proxyName: node.proxy.name,
        testUrl: node.group.testUrl,
      ),
    );
    if (phase != null) {
      return const SizedBox.square(
        dimension: commonCardIconSize,
        child: CommonCircleLoading(),
      );
    }
    if (delay == null) {
      return ExcludeSemantics(
        child: Text(
          '—',
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      );
    }
    return Text(
      delay > 0 ? '$delay ms' : 'Timeout',
      maxLines: 1,
      style: context.textTheme.labelSmall?.copyWith(
        color: context.colorScheme.delayColor(delay),
      ),
    );
  }
}
