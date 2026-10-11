import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'row_card.dart';

/// The nodes of the group the proxies page shows, drawn with that page's own
/// cards: tapping a card pins it, and a card's own button tests its latency.
class PinnedNodesCard extends ConsumerWidget {
  const PinnedNodesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final state = ref.watch(proxiesTabStateProvider);
    final group =
        state.groups.getGroup(state.currentGroupName ?? '') ??
        (state.groups.isEmpty ? null : state.groups.first);
    final proxies = group?.all ?? const <Proxy>[];
    return RowCardFrame(
      child: RowCardPane(
        header: InfoHeader(
          padding: DashboardWidgetMetrics.paddingOf(
            context,
          ).copyWith(bottom: 0),
          info: Info(label: appLocalizations.pinNodes, glyph: AppGlyphs.pin),
        ),
        body: group == null || proxies.isEmpty
            ? RowCardEmpty(
                illustration: NullStatusIllustration.proxies,
                label: appLocalizations.nullTip(appLocalizations.proxyGroup),
              )
            : ListView.separated(
                // Room for the first card's pin badge, which overhangs it.
                padding: const EdgeInsets.only(top: proxyGridSpacing),
                itemCount: proxies.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: proxyGridSpacing),
                itemBuilder: (_, index) {
                  final proxy = proxies[index];
                  return SizedBox(
                    height: getItemHeight(ProxyCardType.min),
                    child: ProxyCard(
                      testUrl: group.testUrl,
                      groupType: group.type,
                      type: ProxyCardType.min,
                      proxy: proxy,
                      groupName: group.name,
                      pinning: true,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
