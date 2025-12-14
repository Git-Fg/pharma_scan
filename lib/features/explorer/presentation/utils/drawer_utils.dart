import 'package:flutter/material.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medication_drawer.dart';
import 'package:pharma_scan/core/ui/organisms/app_sheet.dart';

/// Utility to open the medication drawer sheet for a cluster.
void openMedicationDrawer(BuildContext context, String clusterId) {
  AppSheet.show<void>(
    context: context,
    title: 'Détail du groupe',
    child: MedicationDrawer(clusterId: clusterId),
  );
}
