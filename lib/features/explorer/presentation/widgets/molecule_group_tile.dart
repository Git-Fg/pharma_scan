import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/core/ui/organisms/app_sheet.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MoleculeGroupTile extends HookWidget {
  const MoleculeGroupTile({
    required this.moleculeName,
    required this.princepsName,
    required this.groups,
    required this.itemBuilder,
    super.key,
  });

  final String moleculeName;
  final String princepsName;
  final List<GenericGroupEntity> groups;
  final Widget Function(BuildContext, GenericGroupEntity) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sortedGroups = List<GenericGroupEntity>.from(groups)
      ..sort(
        (a, b) =>
            _naturalCompare(a.princepsReferenceName, b.princepsReferenceName),
      );

    Future<void> openSheet() async {
      await AppSheet.show<void>(
        context: context,
        title: moleculeName,
        child: SingleChildScrollView(
          child: Padding(
            padding: .symmetric(horizontal: spacing.md, vertical: spacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: sortedGroups
                  .map((group) => itemBuilder(context, group))
                  .toList(),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.secondary,
        border: Border.all(color: context.colors.border),
        borderRadius: context.shadTheme.radius,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: openSheet,
        child: SizedBox(
          height: UiSizes.groupHeaderHeight,
          child: Padding(
            padding: .symmetric(horizontal: spacing.md),
            child: Row(
              children: [
                ShadBadge.outline(
                  child: Text(Strings.generics.substring(0, 1)),
                ),
                Gap(spacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        moleculeName,
                        style: context.typo.p.copyWith(fontWeight: .w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(4),
                      Text(
                        princepsName.isNotEmpty
                            ? princepsName
                            : Strings.notDetermined,
                        style: context.typo.small.copyWith(
                          color: context.colors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Gap(spacing.sm),
                Text(
                  Strings.productCount(groups.length),
                  style: context.typo.small.copyWith(
                    color: context.colors.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Gap(spacing.sm),
                const ExcludeSemantics(
                  child: Icon(LucideIcons.chevronRight, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Natural sort comparison that handles numeric values correctly.
  /// Example: "0,5" < "50" < "23" < "300"
  /// This splits strings into text and numeric parts for proper comparison.
  int _naturalCompare(String a, String b) {
    final aParts = _splitNatural(a);
    final bParts = _splitNatural(b);
    final minLength = aParts.length < bParts.length
        ? aParts.length
        : bParts.length;

    for (var i = 0; i < minLength; i++) {
      final aPart = aParts[i];
      final bPart = bParts[i];

      // If both parts are numeric, compare as numbers
      if (aPart.isNumeric && bPart.isNumeric) {
        final aNum = double.tryParse(aPart) ?? 0;
        final bNum = double.tryParse(bPart) ?? 0;
        final diff = aNum.compareTo(bNum);
        if (diff != 0) return diff;
      } else {
        // Compare as strings (case-insensitive for better UX)
        final diff = aPart.toLowerCase().compareTo(bPart.toLowerCase());
        if (diff != 0) return diff;
      }
    }

    // If all parts match, shorter string comes first
    return aParts.length.compareTo(bParts.length);
  }

  /// Splits a string into alternating text and numeric parts.
  /// Example: "PLAVIX 0,5 mg" -> ["PLAVIX ", "0,5", " mg"]
  /// Handles decimal separators (both comma and dot) correctly.
  List<String> _splitNatural(String input) {
    if (input.isEmpty) return [input];

    final parts = <String>[];
    final buffer = StringBuffer();
    bool? isNumeric;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final isDigit = char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
      final isDecimalSep = char == ',' || char == '.';
      final isNumericChar = isDigit || isDecimalSep;

      if (isNumeric == null) {
        // First character - determine type
        isNumeric = isNumericChar;
        buffer.write(char);
      } else if (isNumeric && isNumericChar) {
        // Continue numeric sequence
        buffer.write(char);
      } else if (!isNumeric && !isNumericChar) {
        // Continue text sequence
        buffer.write(char);
      } else {
        // Type change - save current part and start new one
        parts.add(buffer.toString());
        buffer.clear();
        isNumeric = isNumericChar;
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }

    return parts.isEmpty ? [input] : parts;
  }
}

extension _StringNumeric on String {
  bool get isNumeric {
    if (isEmpty) return false;
    final normalized = replaceAll(',', '.');
    return double.tryParse(normalized) != null;
  }
}
