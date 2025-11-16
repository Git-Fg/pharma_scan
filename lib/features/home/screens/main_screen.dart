// lib/features/home/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/features/scanner/screens/camera_screen.dart';
import 'package:pharma_scan/features/explorer/screens/database_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? _groupIdToExplore;

  void _navigateToExplorerWithGroup(String groupId) {
    setState(() {
      _selectedIndex = 1;
      _groupIdToExplore = groupId;
    });
  }

  void _clearGroupExploration() {
    setState(() {
      _groupIdToExplore = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    final List<Widget> screens = [
      CameraScreen(onExploreGroup: _navigateToExplorerWithGroup),
      DatabaseScreen(
        groupIdToExplore: _groupIdToExplore,
        onClearGroup: _clearGroupExploration,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      // WHY: Custom bottom navigation bar using Shadcn theme styling.
      // Positioned at bottom for ergonomic thumb access.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.colorScheme.border)),
          color: theme.colorScheme.background,
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, LucideIcons.scan, 'Scanner', theme),
            _buildNavItem(1, LucideIcons.database, 'Explorer', theme),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    ShadThemeData theme,
  ) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.mutedForeground,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.small.copyWith(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.mutedForeground,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
