import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:pharma_scan/features/explorer/presentation/screens/database_search_view.dart';

@RoutePage(name: 'DatabaseRoute')
class DatabaseScreen extends StatelessWidget {
  const DatabaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DatabaseSearchView();
  }
}

// Note: The database title heading is implemented in DatabaseSearchView
// as this screen is a simple wrapper that delegates to that view.
