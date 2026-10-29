/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../motion.dart';
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ReduceMotionPageTransitionsBuilder(
            PredictiveBackPageTransitionsBuilder(),
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );

    return base.copyWith(
      extensions: [colors, const AppTypography()],
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

/// Swaps the delegate's spatial page transition for a fade when Reduce Motion is on.
class ReduceMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const ReduceMotionPageTransitionsBuilder(this.delegate);

  final PageTransitionsBuilder delegate;

  @override
  Duration get transitionDuration => delegate.transitionDuration;

  @override
  Duration get reverseTransitionDuration => delegate.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition {
    final inner = delegate.delegatedTransition;
    if (inner == null) return null;
    return (context, animation, secondaryAnimation, allowSnapshotting, child) =>
        reduceMotion(context)
        ? null
        : inner(
            context,
            animation,
            secondaryAnimation,
            allowSnapshotting,
            child,
          );
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion(context)) {
      return FadeTransition(
        opacity: animation.drive(CurveTween(curve: AppMotion.easeOut)),
        child: child,
      );
    }
    return delegate.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography();

  static const _textTheme = TextTheme(
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16),
    bodyMedium: TextStyle(fontSize: 14),
    bodySmall: TextStyle(fontSize: 13),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 12),
    labelSmall: TextStyle(fontSize: 11),
    displaySmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );

  TextTheme get textTheme => _textTheme;

  @override
  AppTypography copyWith() => this;

  @override
  AppTypography lerp(AppTypography? other, double t) => this;
}

extension AppTypographyContext on BuildContext {
  TextTheme get appTextTheme =>
      Theme.of(this).extension<AppTypography>()?.textTheme ??
      AppTypography._textTheme;
}
