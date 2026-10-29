/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Corner radii and sizes shared by the flat design.
abstract final class AppShapes {
  static const double card = 16;
  static const double pill = 999;
  static const double screenPadding = 20;
  static const double actionButton = 56;
  static const double voiceButton = 72;
}

/// Material 3 theme built from the locked flat design.
abstract final class AppTheme {
  static const _fontFamily = 'OpenSans';

  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.primary,
          brightness: brightness,
        ).copyWith(
          primary: colors.primary,
          onPrimary: colors.onPrimary,
          surface: colors.background,
          onSurface: colors.onSurfaceStrong,
          onSurfaceVariant: colors.onSurfaceVariant,
          surfaceContainer: colors.surfaceContainer,
          surfaceContainerHigh: colors.surfaceContainerStrong,
          outline: colors.dpadOutline,
          outlineVariant: colors.subtleOutline,
          error: colors.danger,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: colors.background,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      extensions: [colors],
      textTheme: base.textTheme.apply(
        bodyColor: colors.onSurface,
        displayColor: colors.onSurfaceStrong,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colors.appTile,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.card),
          side: BorderSide(color: colors.subtleOutline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(color: colors.subtleOutline, thickness: 1),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.progressTrack,
        thumbColor: colors.primary,
      ),
    );
  }
}
