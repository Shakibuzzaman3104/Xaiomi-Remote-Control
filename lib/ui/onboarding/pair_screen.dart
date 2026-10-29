/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class PairScreen extends StatefulWidget {
  const PairScreen({
    super.key,
    required this.deviceName,
    required this.onSubmit,
    required this.onBack,
    this.onReadAutomatically,
    this.busy = false,
  });

  final String deviceName;
  final Future<String?> Function(String code) onSubmit;
  final VoidCallback onBack;
  final VoidCallback? onReadAutomatically;
  final bool busy;

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
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
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
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
    final text = _controller.text;
    final canSubmit = text.length == 6 && !isBusy;

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
                          color: c.surfaceContainer,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onBack();
                            },
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: c.onSurfaceStrong,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const StepDots(current: 2),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Pair with ${widget.deviceName}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: c.onSurfaceStrong,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the code shown on your TV.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: c.muted),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 60,
                        child: Stack(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (index) {
                                final isFilled = index < text.length;
                                final isFocusedBox =
                                    _focusNode.hasFocus &&
                                    (index == text.length ||
                                        (text.length == 6 && index == 5));
                                final char = isFilled ? text[index] : '';

                                return Container(
                                  width: 46,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: c.appTile,
                                    borderRadius: BorderRadius.circular(
                                      AppShapes.card,
                                    ),
                                    border: Border.all(
                                      color: isFocusedBox
                                          ? c.primary
                                          : c.subtleOutline,
                                      width: isFocusedBox ? 1.5 : 1.0,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: isFilled
                                      ? Text(
                                          char,
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: c.onSurfaceStrong,
                                          ),
                                        )
                                      : (isFocusedBox && index == text.length
                                            ? Container(
                                                width: 2,
                                                height: 24,
                                                color: c.primary,
                                              )
                                            : const SizedBox.shrink()),
                                );
                              }),
                            ),
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.0,
                                child: TextField(
                                  controller: _controller,
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
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.danger,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppShapes.card),
                          border: Border.all(color: c.subtleOutline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
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
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.onSurface,
                                  height: 1.35,
                                ),
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
                    child: ElevatedButton(
                      onPressed: canSubmit
                          ? () {
                              HapticFeedback.selectionClick();
                              _handlePair();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        disabledBackgroundColor: c.surfaceContainerStrong,
                        disabledForegroundColor: c.muted,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppShapes.pill),
                        ),
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      child: isBusy
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.onPrimary,
                              ),
                            )
                          : const Text(
                              'Pair',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              if (widget.onReadAutomatically != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        minWidth: 48,
                      ),
                      child: TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          widget.onReadAutomatically!();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: c.primaryText,
                          minimumSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppShapes.card),
                          ),
                        ),
                        child: Semantics(
                          button: true,
                          label: 'Read code automatically (needs full control)',
                          child: Text(
                            'Read code automatically (needs full control)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.primaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
