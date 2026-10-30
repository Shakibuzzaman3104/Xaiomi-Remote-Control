/**
 * @author Shakib
 * @since 30/10/26
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DiscoverIllustration extends StatelessWidget {
  const DiscoverIllustration({super.key});

  @override
  Widget build(BuildContext context) => _Illustration(
    label: 'TV and phone',
    unlock: false,
    dark: Theme.of(context).brightness == Brightness.dark,
    accent: context.colors.primary,
  );
}

class UnlockIllustration extends StatelessWidget {
  const UnlockIllustration({super.key});

  @override
  Widget build(BuildContext context) => _Illustration(
    label: 'Phone controlling TV settings',
    unlock: true,
    dark: Theme.of(context).brightness == Brightness.dark,
    accent: context.colors.primary,
  );
}

class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.label,
    required this.unlock,
    required this.dark,
    required this.accent,
  });
  final String label;
  final bool unlock;
  final bool dark;
  final Color accent;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    excludeSemantics: true,
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _IllustrationPainter(unlock, dark, accent),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _IllustrationPainter extends CustomPainter {
  const _IllustrationPainter(this.unlock, this.dark, this.accent);
  final bool unlock;
  final bool dark;
  final Color accent;

  Paint fill(Color color) => Paint()..color = color;
  Paint gradient(Rect rect, List<Color> colors) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    ).createShader(rect);
  Paint stroke(Rect rect, List<Color> colors, double width) =>
      gradient(rect, colors)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final height = unlock ? 562.0 : 610.0;
    final scale = math.min(size.width / 840, size.height / height);
    canvas.translate(
      (size.width - 840 * scale) / 2,
      (size.height - height * scale) / 2,
    );
    canvas.scale(scale);
    if (unlock) {
      _unlock(canvas);
    } else {
      _discover(canvas);
    }
  }

  List<Color> get outline => dark
      ? [const Color(0xFF554982), const Color(0xFF302458)]
      : [const Color(0xFF554B86), const Color(0xFF484073)];
  List<Color> get screen => dark
      ? [const Color(0xFF241F32), const Color(0xFF29223C)]
      : [const Color(0xFFE8E4FA), const Color(0xFFD2C9F3)];
  List<Color> get wifi => [
    const Color(0xFF6130F0),
    dark ? accent : const Color(0xFF8F5BFB),
  ];

  void _phone(Canvas c, Rect rect, {bool discover = false}) {
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(22));
    c.drawRRect(
      r,
      gradient(
        rect,
        dark
            ? [const Color(0xFF211C2D), const Color(0xFF211C2D)]
            : [const Color(0xFFF5F3FD), const Color(0xFFE9E4FA)],
      ),
    );
    c.drawRRect(
      r,
      stroke(
        rect,
        discover
            ? (dark
                  ? [const Color(0xFF4E4389), const Color(0xFF1D144D)]
                  : [const Color(0xFF19104D), const Color(0xFF6254A5)])
            : outline,
        discover ? 10 : 12,
      ),
    );
    final x = rect.center.dx;
    final y = discover ? 413.0 : 397.0;
    final p = stroke(Rect.fromLTWH(x - 50, y - 25, 100, 75), wifi, 11);
    c.drawPath(
      Path()
        ..moveTo(x - 40, y)
        ..quadraticBezierTo(x, y - 34, x + 40, y),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(x - 24, y + 19)
        ..quadraticBezierTo(x, y - 1, x + 24, y + 19),
      p,
    );
    if (discover) {
      c.drawPath(
        Path()
          ..moveTo(x - 9, y + 32)
          ..quadraticBezierTo(x, y + 24, x + 9, y + 32),
        p,
      );
      c.drawCircle(
        Offset(x, y + 36),
        8,
        gradient(Rect.fromLTWH(x - 10, y + 26, 20, 20), wifi),
      );
    } else {
      c.drawCircle(
        Offset(x, y + 40),
        11,
        gradient(Rect.fromLTWH(x - 11, y + 29, 22, 22), wifi),
      );
    }
  }

  void _discover(Canvas c) {
    c.drawCircle(
      const Offset(414, 343),
      342,
      fill(dark ? const Color(0xFF211C2E) : const Color(0xFFECE9FA)),
    );
    c.drawCircle(
      const Offset(414, 343),
      245,
      fill(dark ? const Color(0xFF231E31) : const Color(0xFFDFD9F7)),
    );
    c.drawOval(
      const Rect.fromLTWH(1, 509, 826, 100),
      fill(dark ? const Color(0xFF262034) : const Color(0xFFE4DFF8)),
    );
    _sparkle(c, const Offset(46, 246), 18);
    _sparkle(c, const Offset(748, 100), 24);
    final stand = Path()
      ..moveTo(547, 501)
      ..lineTo(594, 503)
      ..lineTo(594, 535)
      ..cubicTo(647, 537, 687, 542, 686, 552)
      ..quadraticBezierTo(685, 557, 677, 556)
      ..lineTo(457, 546)
      ..quadraticBezierTo(448, 546, 452, 540)
      ..cubicTo(457, 534, 505, 533, 547, 533)
      ..close();
    c.drawPath(
      stand,
      gradient(
        const Rect.fromLTWH(450, 500, 240, 58),
        dark
            ? [const Color(0xFF51458F), const Color(0xFF403478)]
            : [const Color(0xFF493E92), const Color(0xFF5D52AA)],
      ),
    );
    final tv = Path()
      ..moveTo(336, 215)
      ..lineTo(831, 170)
      ..quadraticBezierTo(835, 170, 835, 176)
      ..lineTo(835, 516)
      ..quadraticBezierTo(835, 522, 829, 521)
      ..lineTo(336, 499)
      ..quadraticBezierTo(331, 499, 331, 493)
      ..lineTo(331, 221)
      ..quadraticBezierTo(331, 216, 336, 215)
      ..close();
    const bounds = Rect.fromLTWH(327, 165, 510, 360);
    c.drawPath(tv, gradient(bounds, screen));
    c.drawPath(
      tv,
      stroke(
        bounds,
        dark
            ? [const Color(0xFF554BA7), const Color(0xFF3E3287)]
            : [const Color(0xFF4A4297), const Color(0xFF5145A3)],
        10,
      ),
    );
    _phone(c, const Rect.fromLTWH(92, 290, 151, 279), discover: true);
  }

  void _sparkle(Canvas c, Offset center, double radius) {
    final p = stroke(
      Rect.fromCircle(center: center, radius: radius),
      dark
          ? [const Color(0xFF29233B), const Color(0xFF40365C)]
          : [const Color(0xFFD2C8F7), const Color(0xFFC1B4EE)],
      radius * .48,
    );
    for (final d in [
      const Offset(0, -1),
      const Offset(1, 0),
      const Offset(0, 1),
      const Offset(-1, 0),
    ]) {
      c.drawLine(center + d * (radius * .36), center + d * radius, p);
    }
  }

  void _unlock(Canvas c) {
    final blob = Path()
      ..moveTo(1, 334)
      ..cubicTo(1, 251, 106, 211, 171, 151)
      ..cubicTo(249, 78, 317, 1, 414, 1)
      ..cubicTo(527, 1, 604, 80, 674, 149)
      ..cubicTo(751, 225, 827, 303, 799, 441)
      ..cubicTo(778, 553, 666, 548, 539, 519)
      ..cubicTo(407, 489, 317, 505, 203, 507)
      ..cubicTo(94, 509, 1, 464, 1, 334)
      ..close();
    c.drawPath(
      blob,
      fill(dark ? const Color(0xFF211C2E) : const Color(0xFFE9E3FA)),
    );
    c.drawOval(
      const Rect.fromLTWH(29, 524, 272, 37),
      fill(dark ? const Color(0xFF292138) : const Color(0xFFD8D0F3)),
    );
    c.drawOval(
      const Rect.fromLTWH(342, 454, 417, 46),
      fill(dark ? const Color(0xFF262034) : const Color(0xFFD8D0F3)),
    );
    for (final point in [
      const Offset(169, 271),
      const Offset(188, 247),
      const Offset(212, 227),
      const Offset(240, 211),
      const Offset(270, 200),
    ]) {
      c.drawCircle(
        point,
        7.5,
        gradient(const Rect.fromLTWH(160, 190, 120, 90), wifi),
      );
    }
    final stand = Path()
      ..moveTo(539, 434)
      ..lineTo(587, 434)
      ..lineTo(587, 459)
      ..cubicTo(618, 460, 648, 462, 654, 466)
      ..quadraticBezierTo(661, 472, 655, 478)
      ..lineTo(470, 478)
      ..quadraticBezierTo(465, 473, 471, 467)
      ..cubicTo(479, 462, 509, 460, 539, 459)
      ..close();
    c.drawPath(
      stand,
      gradient(const Rect.fromLTWH(468, 430, 190, 50), outline),
    );
    const tv = Rect.fromLTWH(294, 122, 545, 323);
    c.drawRRect(
      RRect.fromRectAndRadius(tv, const Radius.circular(18)),
      gradient(tv, outline),
    );
    const inner = Rect.fromLTWH(310, 137, 514, 289);
    c.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(7)),
      gradient(inner, screen),
    );
    const panel = Rect.fromLTWH(412, 193, 381, 180);
    c.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(19)),
      fill(dark ? const Color(0xFF201B2C) : const Color(0xFFF0EDFC)),
    );
    final bar = dark ? const Color(0xFF292138) : const Color(0xFFD5CEF4);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(574, 238, 186, 33),
        const Radius.circular(20),
      ),
      fill(bar),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(574, 293, 143, 33),
        const Radius.circular(20),
      ),
      fill(bar),
    );
    _gear(c, const Offset(493, 283));
    _phone(c, const Rect.fromLTWH(83, 297, 153, 247));
  }

  void _gear(Canvas c, Offset center) {
    final path = Path();
    for (var i = 0; i < 64; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 64;
      final phase = i % 8;
      final radius = phase == 0 || phase == 1 || phase == 7 ? 52.0 : 42.0;
      final point =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    c.drawPath(
      path,
      gradient(Rect.fromCircle(center: center, radius: 52), outline),
    );
    c.drawCircle(
      center,
      17,
      fill(dark ? const Color(0xFF201B2C) : const Color(0xFFF0EDFC)),
    );
  }

  @override
  bool shouldRepaint(_IllustrationPainter oldDelegate) =>
      unlock != oldDelegate.unlock ||
      dark != oldDelegate.dark ||
      accent != oldDelegate.accent;
}
