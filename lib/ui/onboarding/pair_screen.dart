/**
 * @author Shakib
 * @since 29/10/26
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../haptics.dart';
import '../motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'step_dots.dart';

class _UpperCaseHexFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

double _shakeOffset(double t) => math.sin(t * math.pi * 6) * 8 * (1 - t);

class PairScreen extends StatefulWidget {
  const PairScreen({
    super.key,
    required this.deviceName,
    required this.onSubmit,
    required this.onBack,
    this.startError,
    this.onRetryStart,
    this.busy = false,
    this.success = false,
  });

  final String deviceName;
  final Future<String?> Function(String code) onSubmit;
  final VoidCallback onBack;
  final String? startError;
  final VoidCallback? onRetryStart;
  final bool busy;
  final bool success;

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
      if (_controller.text.length == 6 &&
          !widget.busy &&
          widget.startError == null &&
          !_submitting &&
          !widget.success) {
        _handlePair();
      }
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant PairScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.success && widget.success) AppHaptics.light();
  }

  @override
  void dispose() {
    _shake.dispose();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handlePair() async {
    final code = _controller.text.trim();
    if (code.length != 6 || widget.busy || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final err = await widget.onSubmit(code);
    if (!mounted) return;

    if (err != null) {
      AppHaptics.medium();
      if (!reduceMotion(context)) _shake.forward(from: 0);
      _controller.clear();
      setState(() {
        _submitting = false;
        _error = err;
      });
      _focusNode.requestFocus();
    } else {
      setState(() {
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isBusy = widget.busy || _submitting;
    final deviceLabel = widget.deviceName.replaceFirst(
      RegExp(r' (?=[^ ]+$)'),
      '\u00A0',
    );
    final text = _controller.text;
    final canSubmit =
        text.length == 6 &&
        !isBusy &&
        widget.startError == null &&
        !widget.success;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppShapes.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        button: true,
                        label: 'Back',
                        child: Material(
                          color: c.background,
                          shape: CircleBorder(
                            side: BorderSide(color: c.subtleOutline),
                          ),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              AppHaptics.selection();
                              widget.onBack();
                            },
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(
                                Theme.of(context).platform == TargetPlatform.iOS
                                    ? Icons.arrow_back_ios_new
                                    : Icons.arrow_back,
                                color: c.onSurfaceStrong,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const StepDots(current: 2, numbered: false),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Pair with $deviceLabel',
                        textAlign: TextAlign.center,
                        style: context.appTextTheme.headlineMedium!.copyWith(
                          color: c.onSurfaceStrong,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.busy
                            ? 'Connecting to ${widget.deviceName}…'
                            : 'Enter the code shown on your TV.',
                        textAlign: TextAlign.center,
                        style: context.appTextTheme.bodyLarge!.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 42),
                      SizedBox(
                        height: 72,
                        child: AnimatedBuilder(
                          animation: _shake,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(_shakeOffset(_shake.value), 0),
                            child: child,
                          ),
                          child: Stack(
                            children: [
                              ExcludeSemantics(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(6, (index) {
                                    final isFilled = index < text.length;
                                    final isFocusedBox =
                                        _focusNode.hasFocus &&
                                        (index == text.length ||
                                            (text.length == 6 && index == 5));
                                    final char = isFilled ? text[index] : '';

                                    return Expanded(
                                      child: AnimatedContainer(
                                        duration: motion(
                                          context,
                                          AppMotion.quick,
                                        ),
                                        curve: AppMotion.easeOut,
                                        margin: EdgeInsets.only(
                                          right: index == 5 ? 0 : 7,
                                        ),
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: c.background,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: widget.success
                                                ? c.primary
                                                : _error != null
                                                ? c.danger
                                                : isFocusedBox
                                                ? c.primary
                                                : c.inputOutline,
                                            width: isFocusedBox ? 1.5 : 1.0,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: isFilled
                                            ? _PopIn(
                                                key: ValueKey('$index$char'),
                                                child: Text(
                                                  char,
                                                  style: context
                                                      .appTextTheme
                                                      .headlineMedium!
                                                      .copyWith(
                                                        color:
                                                            c.onSurfaceStrong,
                                                      ),
                                                ),
                                              )
                                            : (isFocusedBox &&
                                                      index == text.length
                                                  ? Container(
                                                      width: 2,
                                                      height: 24,
                                                      color: c.primary,
                                                    )
                                                  : const SizedBox.shrink()),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.0,
                                  alwaysIncludeSemantics: true,
                                  child: TextField(
                                    controller: _controller,
                                    enabled:
                                        !widget.busy &&
                                        widget.startError == null &&
                                        !widget.success,
                                    decoration: const InputDecoration(
                                      labelText: '6-digit pairing code',
                                    ),
                                    focusNode: _focusNode,
                                    autofocus: true,
                                    keyboardType: TextInputType.text,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9a-fA-F]'),
                                      ),
                                      LengthLimitingTextInputFormatter(6),
                                      _UpperCaseHexFormatter(),
                                    ],
                                    onChanged: (_) {
                                      if (_error != null) {
                                        setState(() => _error = null);
                                      }
                                    },
                                    onSubmitted: (_) => _handlePair(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_error != null || widget.startError != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            widget.startError ?? _error!,
                            textAlign: TextAlign.center,
                            style: context.appTextTheme.labelLarge!.copyWith(
                              color: c.danger,
                            ),
                          ),
                        ),
                      ],
                      if (widget.startError != null ||
                          _error == 'The code expired. Get a new one.')
                        TextButton(
                          onPressed: () {
                            _controller.clear();
                            setState(() => _error = null);
                            widget.onRetryStart?.call();
                          },
                          child: Text(
                            widget.startError != null
                                ? 'Try again'
                                : 'Get a new code',
                          ),
                        ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppShapes.card),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.okButton,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.tv_rounded,
                                size: 22,
                                color: c.onSurfaceStrong,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                "Can't see a code? Turn on the TV and keep it on the home screen.",
                                style: context.appTextTheme.bodyMedium!
                                    .copyWith(color: c.onSurface, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Semantics(
                  button: true,
                  label: 'Pair',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: FilledButton(
                      onPressed: canSubmit
                          ? () {
                              AppHaptics.selection();
                              _handlePair();
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        disabledBackgroundColor: widget.success
                            ? c.primary
                            : c.surfaceContainerStrong,
                        disabledForegroundColor: widget.success
                            ? c.onPrimary
                            : c.onSurfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppShapes.pill),
                        ),
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      child: widget.success
                          ? _CheckMark(color: c.onPrimary)
                          : isBusy
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.onPrimary,
                              ),
                            )
                          : Text(
                              'Pair',
                              style: context.appTextTheme.bodyLarge!.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopIn extends StatelessWidget {
  const _PopIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.quick,
      curve: AppMotion.easeOut,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
      ),
    );
  }
}

class _CheckMark extends StatefulWidget {
  const _CheckMark({required this.color});
  final Color color;

  @override
  State<_CheckMark> createState() => _CheckMarkState();
}

class _CheckMarkState extends State<_CheckMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.animateTo(
        1,
        duration: motion(context, AppMotion.standard),
        curve: AppMotion.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Paired',
    child: CustomPaint(
      size: const Size.square(26),
      painter: _CheckPainter(widget.color, _controller),
    ),
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.color, this.progress) : super(repaint: progress);
  final Color color;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.54)
      ..lineTo(size.width * 0.4, size.height * 0.76)
      ..lineTo(size.width * 0.82, size.height * 0.28);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress.value),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color;
}
