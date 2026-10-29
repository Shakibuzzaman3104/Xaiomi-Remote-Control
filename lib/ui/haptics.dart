/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/services.dart';

abstract final class AppHaptics {
  static bool enabled = true;

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
