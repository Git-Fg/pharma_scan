import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:talker_flutter/talker_flutter.dart';

final talkerProvider = Provider<Talker>((ref) {
  return LoggerService().talker;
});
