import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:talker_flutter/talker_flutter.dart';

@RoutePage(name: 'LogsRoute')
class LogsScreenWrapper extends StatelessWidget {
  const LogsScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = context.shadColors.background;
    return TalkerScreen(
      talker: LoggerService().talker,
      theme: TalkerScreenTheme(
        backgroundColor: backgroundColor,
      ),
    );
  }
}
