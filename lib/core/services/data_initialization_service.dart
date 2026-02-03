export 'data_initialization_models.dart';

export 'data_initialization_service_native.dart'
    if (dart.library.html) 'data_initialization_service_web.dart';
