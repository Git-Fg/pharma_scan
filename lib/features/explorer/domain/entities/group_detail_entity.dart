import 'package:pharma_scan/core/database/database.dart';

/// Extension type wrapping [ViewGroupDetail] to decouple UI from Drift rows.
extension type GroupDetailEntity(ViewGroupDetail _data)
    implements ViewGroupDetail {
  GroupDetailEntity.fromData(ViewGroupDetail data) : this(data);

  bool get isRevoked => status?.toLowerCase().contains('abrog') ?? false;

  bool get isNotMarketed =>
      status?.toLowerCase().contains('non commercialis') ?? false;
}
