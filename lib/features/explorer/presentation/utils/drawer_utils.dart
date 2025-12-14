import 'package:flutter/material.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medication_drawer.dart';
import 'package:pharma_scan/core/ui/organisms/app_sheet.dart';

/// Utility function to open medication drawer
void _openDrawer(BuildContext context, String clusterId) {
  AppSheet.show(
    context: context,
    title: 'Détail du groupe',
    child: MedicationDrawer(clusterId: clusterId),
  );
}
