import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:talker_flutter/talker_flutter.dart';

part 'logger_provider.g.dart';

@Riverpod(keepAlive: true)
Talker talker(Ref ref) => LoggerService().talker;
