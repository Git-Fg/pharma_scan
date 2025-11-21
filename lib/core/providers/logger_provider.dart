import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../services/logger_service.dart';

final talkerProvider = Provider<Talker>((ref) {
  return LoggerService().talker;
});
