// lib/features/explorer/screens/database_screen.dart
import 'package:flutter/material.dart';
import 'package:pharma_scan/features/explorer/screens/database_search_view.dart';
import 'package:pharma_scan/features/explorer/screens/group_explorer_view.dart';

class DatabaseScreen extends StatefulWidget {
  final String? groupIdToExplore;
  final VoidCallback onClearGroup;

  const DatabaseScreen({
    this.groupIdToExplore,
    required this.onClearGroup,
    super.key,
  });

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  String? _currentGroupId;

  @override
  void initState() {
    super.initState();
    _currentGroupId = widget.groupIdToExplore;
  }

  @override
  void didUpdateWidget(covariant DatabaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.groupIdToExplore != _currentGroupId) {
      setState(() {
        _currentGroupId = widget.groupIdToExplore;
      });
    }
  }

  void _handleGroupSelected(String groupId) {
    setState(() {
      _currentGroupId = groupId;
    });
  }

  void _handleExitGroup() {
    setState(() {
      _currentGroupId = null;
    });
    widget.onClearGroup();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGroupId != null) {
      return GroupExplorerView(
        groupId: _currentGroupId!,
        onExit: _handleExitGroup,
      );
    }

    return DatabaseSearchView(onGroupSelected: _handleGroupSelected);
  }
}
