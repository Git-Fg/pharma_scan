import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Enumération des icônes standards de l'application
enum AppIconData {
  // Actions
  add(Icons.add),
  remove(Icons.remove),
  edit(Icons.edit),
  delete(Icons.delete),
  save(Icons.save),
  cancel(Icons.cancel),
  close(Icons.close),
  back(Icons.arrow_back),
  forward(Icons.arrow_forward),
  menu(Icons.menu),
  search(Icons.search),
  filter(Icons.filter_list),
  sort(Icons.sort),
  share(Icons.share),
  download(Icons.download),
  upload(Icons.upload),
  refresh(Icons.refresh),
  settings(Icons.settings),
  help(Icons.help),
  info(Icons.info),
  warning(Icons.warning),
  error(Icons.error),
  success(Icons.check_circle),
  star(Icons.star),
  favorite(Icons.favorite),
  bookmark(Icons.bookmark),
  shareAlt(Icons.share),
  
  // Navigation
  home(Icons.home),
  dashboard(Icons.dashboard),
  profile(Icons.person),
  notifications(Icons.notifications),
  messages(Icons.message),
  calendar(Icons.calendar_today),
  location(Icons.location_on),
  map(Icons.map),
  
  // Communication
  email(Icons.email),
  phone(Icons.phone),
  sms(Icons.sms),
  video(Icons.videocam),
  camera(Icons.camera_alt),
  
  // Médical (spécifique à PharmaScan)
  pill(Icons.local_pharmacy),
  scanner(Icons.qr_code_scanner),
  history(Icons.history),
  barcode(Icons.qr_code),
  prescription(Icons.medication);

  const AppIconData(this.icon);
  final IconData icon;
}

/// Widget d'icône standardisé
class AppIcon extends StatelessWidget {
  const AppIcon(
    AppIconData? iconData, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  }) : iconData = iconData, customIcon = null;

  /// Constructeur pour utiliser une icône personnalisée
  const AppIcon.custom(
    IconData? customIcon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  }) : iconData = null, customIcon = customIcon;

  final AppIconData? iconData;
  final IconData? customIcon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final icon = iconData?.icon ?? customIcon;
    assert(icon != null, 'Either iconData or customIcon must be provided');

    return Semantics(
      label: semanticLabel,
      excludeSemantics: excludeFromSemantics,
      child: Icon(
        icon,
        size: size,
        color: color ?? context.textPrimary,
      ),
    );
  }
}

/// Extension sur BuildContext pour accéder aux tailles d'icônes standardisées
extension IconSizeExtension on BuildContext {
  double get iconSizeSmall => 16.0;
  double get iconSizeMedium => 20.0;
  double get iconSizeLarge => 24.0;
  double get iconSizeXLarge => 32.0;
  double get iconSizeXXLarge => 40.0;
}