import 'package:flutter/services.dart';

/// Service centralisé pour les retours haptiques.
class HapticService {
  const HapticService();

  /// Vibration courte et légère (succès discret).
  Future<void> success() async {
    await HapticFeedback.lightImpact();
  }

  /// Vibration moyenne pour attirer l'attention (alerte).
  Future<void> warning() async {
    await HapticFeedback.mediumImpact();
  }

  /// Vibration lourde pour signaler une erreur.
  Future<void> error() async {
    await HapticFeedback.heavyImpact();
  }

  /// Clic de sélection très léger.
  Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }
}
