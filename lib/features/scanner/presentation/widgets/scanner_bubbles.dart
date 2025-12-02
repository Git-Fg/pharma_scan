import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_card.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_type_badge.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Widget that displays the stack of scan result bubbles at the top of the camera screen.
///
/// Handles:
/// - Responsive margins (8px for small screens, 12px otherwise)
/// - Dismissible swipe-to-remove functionality
/// - Bubble entrance animations
class ScannerBubbles extends HookConsumerWidget {
  const ScannerBubbles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Builder(
        builder: (context) {
          final breakpoint = context.breakpoint;
          final horizontalMargin =
              breakpoint < ShadTheme.of(context).breakpoints.sm ? 8.0 : 12.0;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
            child: Consumer(
              builder: (context, ref, child) {
                final scannerState = ref.watch(scannerProvider);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < scannerState.bubbles.length; i++)
                      _buildBubbleItem(
                        context,
                        ref,
                        scannerState.bubbles[i],
                        i,
                      ),
                  ],
                ).animate(effects: AppAnimations.bubbleEnter);
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
    int index,
  ) {
    final isPrimary = index == 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: AppDimens.spacing2xs / 2,
        top: isPrimary ? 0 : AppDimens.spacing2xs / 2,
      ),
      child: Dismissible(
        key: ValueKey(bubble.cip),
        onDismissed: (_) =>
            ref.read(scannerProvider.notifier).removeBubble(bubble.cip),
        child: _buildBubbleContent(context, ref, bubble),
      ),
    );
  }

  Widget _buildBubbleContent(
    BuildContext context,
    WidgetRef ref,
    ScanBubble bubble,
  ) {
    final summary = bubble.summary;

    // Determine product type
    final productType = summary.groupId != null
        ? (summary.isPrinceps ? ProductType.princeps : ProductType.generic)
        : ProductType.standalone;

    // Build badges based on product type
    final badges = <Widget>[
      ProductTypeBadge(type: productType, compact: true),
    ];

    // Condition badge
    if (summary.conditionsPrescription != null &&
        summary.conditionsPrescription!.isNotEmpty) {
      badges.add(
        ShadBadge.outline(
          child: Text(
            summary.conditionsPrescription!,
            style: ShadTheme.of(context).textTheme.small,
          ),
        ),
      );
    }

    // Compact subtitle lines for scanner bubbles:
    // Line 1: Form & Dosage (e.g., "Comprimé • 10 mg")
    // Line 2: Titulaire (Lab) & CIP (e.g., "BIOGARAN • CIP: 34009...")
    final compactSubtitle = <String>[];
    final form = summary.formePharmaceutique;
    final dosage = summary.formattedDosage?.trim();

    if (form != null &&
        form.isNotEmpty &&
        dosage != null &&
        dosage.isNotEmpty) {
      compactSubtitle.add('$form • $dosage');
    } else if (form != null && form.isNotEmpty) {
      compactSubtitle.add(form);
    } else if (dosage != null && dosage.isNotEmpty) {
      compactSubtitle.add(dosage);
    }

    final titulaire = summary.titulaire;
    final cipLine = (titulaire != null && titulaire.isNotEmpty)
        ? '${titulaire.trim()} • ${Strings.cip} ${bubble.cip}'
        : '${Strings.cip} ${bubble.cip}';
    compactSubtitle.add(cipLine);

    return ProductCard(
      key: ValueKey(
        '${bubble.cip}_${summary.isPrinceps
            ? 'princeps'
            : summary.groupId != null
            ? 'generic'
            : 'standalone'}',
      ),
      summary: summary,
      cip: bubble.cip,
      compact: true,
      showDetails: false,
      subtitle: compactSubtitle,
      groupLabel: summary.groupId != null ? summary.princepsBrandName : null,
      badges: badges,
      showActions: true,
      animation: true,
      onClose: () =>
          ref.read(scannerProvider.notifier).removeBubble(bubble.cip),
      onExplore: summary.groupId != null
          ? () => context.router.push(
              GroupExplorerRoute(groupId: summary.groupId!),
            )
          : null,
      price: bubble.price,
      refundRate: bubble.refundRate,
      boxStatus: bubble.boxStatus,
      availabilityStatus: bubble.availabilityStatus,
      isHospitalOnly: bubble.isHospitalOnly,
      exactMatchLabel: bubble.libellePresentation,
    );
  }
}
