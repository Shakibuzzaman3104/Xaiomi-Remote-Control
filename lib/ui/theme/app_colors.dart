/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

/// Colours measured from the locked Remote design and its dark variant.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surfaceContainer,
    required this.surfaceContainerStrong,
    required this.okButton,
    required this.dpadOutline,
    required this.subtleOutline,
    required this.appTile,
    required this.primary,
    required this.primaryText,
    required this.onPrimary,
    required this.onSurfaceStrong,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.muted,
    required this.progressTrack,
    required this.connected,
    required this.danger,
  });

  final Color background;
  final Color surfaceContainer;
  final Color surfaceContainerStrong;
  final Color okButton;
  final Color dpadOutline;
  final Color subtleOutline;
  final Color appTile;
  final Color primary;
  final Color primaryText;
  final Color onPrimary;
  final Color onSurfaceStrong;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color muted;
  final Color progressTrack;
  final Color connected;
  final Color danger;

  static const light = AppColors(
    background: Color(0xFFF7F5FC),
    surfaceContainer: Color(0xFFECE9F5),
    surfaceContainerStrong: Color(0xFFE4E0F0),
    okButton: Color(0xFFE4DDF7),
    dpadOutline: Color(0xFFDFDAF1),
    subtleOutline: Color(0xFFECEAF8),
    appTile: Color(0xFFFBFAFE),
    primary: Color(0xFF6041B4),
    primaryText: Color(0xFF5628CE),
    onPrimary: Color(0xFFF7F5FC),
    onSurfaceStrong: Color(0xFF050425),
    onSurface: Color(0xFF3C3654),
    onSurfaceVariant: Color(0xFF464261),
    muted: Color(0xFF676186),
    progressTrack: Color(0xFFDEDBED),
    connected: Color(0xFF1E8E3E),
    danger: Color(0xFFC62828),
  );

  static const dark = AppColors(
    background: Color(0xFF110F14),
    surfaceContainer: Color(0xFF201D25),
    surfaceContainerStrong: Color(0xFF292532),
    okButton: Color(0xFF332A49),
    dpadOutline: Color(0xFF2E2B37),
    subtleOutline: Color(0xFF2A2731),
    appTile: Color(0xFF1F1C24),
    primary: Color(0xFF6F51D6),
    primaryText: Color(0xFF9D7BF4),
    onPrimary: Color(0xFFFFFFFF),
    onSurfaceStrong: Color(0xFFF6F4FC),
    onSurface: Color(0xFFE6E2F2),
    onSurfaceVariant: Color(0xFFC9C3DE),
    muted: Color(0xFFA39CC4),
    progressTrack: Color(0xFF332E3F),
    connected: Color(0xFF5BC57A),
    danger: Color(0xFFEF6F6C),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
