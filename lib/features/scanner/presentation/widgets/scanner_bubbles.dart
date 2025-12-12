import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:pharma_scan/features/scanner/presentation/widgets/scanner_result_card.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Widget that displays the stack of scan result bubbles at the top of the camera screen.
///
/// Handles:
/// - Responsive margins (8px for small screens, 12px otherwise)
/// - Dismissible swipe-to-remove functionality
/// - Bubble entrance animations
class ScannerBubbles extends ConsumerWidget {
  const ScannerBubbles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topOffset =
        MediaQuery.paddingOf(context).top +
        AppDimens.spacingMd +
        AppDimens.iconLg +
        AppDimens.spacingSm;

    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Builder(
        builder: (context) {
          final breakpoint = context.breakpoint;
          final horizontalMargin = breakpoint < context.breakpoints.sm
              ? 8.0
              : 12.0;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
            child: Consumer(
              builder: (context, ref, child) {
                final scannerAsync = ref.watch(scannerProvider);
                final scannerState = scannerAsync.value;

                if (scannerState == null || scannerState.bubbles.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < scannerState.bubbles.length; i++)
                      _buildBubbleItem(
                        context,
                        ref,
                        scannerState.bubbles[i],
                        scannerState.mode,
                        i,
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBubbleItem(
    BuildContext context,
    WidgetRef ref,
    ScanBubble bubble,
    ScannerMode mode,
    int index,
  ) {
    final isPrimary = index == 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: AppDimens.spacing2xs / 2,
        top: isPrimary ? 0 : AppDimens.spacing2xs / 2,
      ),
      child: Dismissible(
        key: ValueKey(bubble.cip.toString()),
        onDismissed: (_) => ref
            .read(scannerProvider.notifier)
            .removeBubble(bubble.cip.toString()),
        child: _buildBubbleContent(
          context,
          ref,
          bubble,
          mode,
        ),
      ),
    );
  }

  Widget _buildBubbleContent(
    BuildContext context,
    WidgetRef ref,
    ScanBubble bubble,
    ScannerMode mode,
  ) {
    final summary = bubble.summary;
    final isGenericWithPrinceps =
        !summary.data.isPrinceps &&
        summary.groupId != null &&
        summary.data.princepsDeReference.isNotEmpty &&
        summary.data.princepsDeReference != 'Inconnu';

    final badges = <Widget>[
      ProductTypeBadge(
        memberType: summary.data.memberType,
        compact: true,
      ),
    ];

    if (summary.conditionsPrescription.isNotEmpty) {
      badges.add(
        ShadBadge.outline(
          child: Text(
            summary.conditionsPrescription,
            style: context.shadTextTheme.small,
          ),
        ),
      );
    }

    final compactSubtitle = <String>[];
    if (isGenericWithPrinceps &&
        summary.data.nomCanonique.isNotEmpty &&
        summary.data.nomCanonique.trim().isNotEmpty) {
      compactSubtitle.add(summary.data.nomCanonique.trim());
    }
    final form = summary.formePharmaceutique.trim();
    final dosage = summary.formattedDosage.trim();

    if (form.isNotEmpty && dosage.isNotEmpty) {
      compactSubtitle.add('$form • $dosage');
    } else if (form.isNotEmpty) {
      compactSubtitle.add(form);
    } else if (dosage.isNotEmpty) {
      compactSubtitle.add(dosage);
    }

    final titulaire = summary.titulaire;
    final cipString = bubble.cip.toString();
    final cipLine = (titulaire != null && titulaire.isNotEmpty)
        ? '${titulaire.trim()} • ${Strings.cip} $cipString'
        : '${Strings.cip} $cipString';
    compactSubtitle.add(cipLine);

    return ScannerResultCard(
      key: ValueKey(
        '${cipString}_${summary.data.isPrinceps
            ? 'princeps'
            : summary.groupId != null
            ? 'generic'
            : 'standalone'}',
      ),
      summary: summary,
      cip: bubble.cip,
      badges: badges,
      subtitle: compactSubtitle,
      mode: mode,
      onClose: () => ref.read(scannerProvider.notifier).removeBubble(cipString),
      onExplore: summary.groupId != null
          ? () => AutoRouter.of(context).push(
              GroupExplorerRoute(groupId: summary.groupId!.toString()),
            )
          : null,
      price: bubble.price,
      refundRate: bubble.refundRate,
      boxStatus: bubble.boxStatus,
      availabilityStatus: bubble.availabilityStatus,
      isHospitalOnly: bubble.isHospitalOnly,
      exactMatchLabel: bubble.libellePresentation,
      expDate: bubble.expDate,
      isExpired: bubble.isExpired,
    );
  }
}
