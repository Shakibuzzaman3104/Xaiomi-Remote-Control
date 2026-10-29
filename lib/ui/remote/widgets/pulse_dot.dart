/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';

import '../../motion.dart';
import '../../theme/app_colors.dart';

class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.size = 8});
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary;
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
    return AnimatedBuilder(
      animation: _controller,
      child: dot,
      builder: (context, dot) {
        final t = AppMotion.easeOut.transform(_controller.value);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (_controller.value > 0)
              Opacity(
                opacity: 0.45 * (1 - t),
                child: Transform.scale(
                  scale: 1 + 1.4 * t,
                  child: SizedBox.square(
                    dimension: widget.size,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            dot!,
          ],
        );
      },
    );
  }
}
