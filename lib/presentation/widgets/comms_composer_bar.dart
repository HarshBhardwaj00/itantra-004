import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/layout_utils.dart';

/// Bottom text composer — the keyboard-safe "add record" form of the hub.
///
/// Designed with a modern, square-shaped tactical aesthetic:
/// - Crisp squircle text field with ~8–10px corner radius.
/// - Matching square-shaped Send action button with clean geometric bounds.
/// - Isolated ValueListenableBuilder for reactive typing without full-tree rebuilds.
/// - Bounded Row and FittedBox constraints to prevent any RenderFlex overflow.
class CommsComposerBar extends StatelessWidget {
  const CommsComposerBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.focusNode,
    this.hint = 'Type message',
    this.enabled = true,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final FocusNode? focusNode;
  final String hint;
  final bool enabled;

  void _handleSend() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    onSend();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Professional typography: 14.0–15.5 sp for comfortable, readable messaging
    final fieldSize = clampDouble(screenWidth * 0.038, 14.0, 15.5);
    final buttonSize = clampDouble(screenWidth * 0.036, 13.0, 14.5);
    final gap = clampDouble(screenWidth * 0.020, 6.0, 10.0);

    final hContentPad = clampDouble(screenWidth * 0.035, 12.0, 16.0);
    final vContentPad = clampDouble(screenWidth * 0.028, 11.0, 15.0);

    // Square-shaped tactical radii (clean squircle corners)
    final outerRadius = clampDouble(screenWidth * 0.035, 12.0, 14.0);
    final fieldRadius = clampDouble(screenWidth * 0.025, 8.0, 10.0);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : screenWidth;

          final outerHp = clampDouble(availableWidth * 0.022, 4.0, 12.0);
          final outerVp = clampDouble(availableWidth * 0.016, 4.0, 10.0);

          // The send button never claims more than 40% of the inner row, so the
          // only stretchable item (the field) always has room.
          final maxButtonWidth = math.max(
            36.0,
            (availableWidth - outerHp * 2) * 0.40,
          );

          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(outerRadius),
              border: Border.all(color: AppColors.surfaceBorder, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.06),
                  blurRadius: 18.0,
                  offset: const Offset(0.0, 4.0),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              horizontal: outerHp,
              vertical: outerVp,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      TextField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: enabled,
                        // Grows smoothly up to three lines before scrolling
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        style: TextStyle(
                          fontSize: fieldSize,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                        cursorColor: AppColors.primaryEmerald,
                        scrollPadding: const EdgeInsets.only(bottom: 96.0),
                        onSubmitted: (_) => _handleSend(),
                        decoration: InputDecoration(
                          isDense: true,
                          // The placeholder is drawn by hand below so the field
                          // never falls back to Flutter's ellipsising hint.
                          hintText: null,
                          filled: true,
                          fillColor: AppColors.surfaceSecondary,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: hContentPad,
                            vertical: vContentPad,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(fieldRadius),
                            borderSide: const BorderSide(
                              color: AppColors.surfaceBorder,
                              width: 1.0,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(fieldRadius),
                            borderSide: const BorderSide(
                              color: AppColors.surfaceBorder,
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(fieldRadius),
                            borderSide: const BorderSide(
                              color: AppColors.primaryEmerald,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) {
                          if (value.text.trim().isNotEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Positioned.fill(
                            child: IgnorePointer(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: hContentPad + 1.5,
                                  right: hContentPad,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    hint,
                                    style: TextStyle(
                                      fontSize: fieldSize,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.textMuted,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: gap),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxButtonWidth),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final canSend = enabled && value.text.trim().isNotEmpty;
                      return _SendButton(
                        enabled: canSend,
                        label: 'Send',
                        fontSize: buttonSize,
                        onTap: _handleSend,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.label,
    required this.fontSize,
    required this.onTap,
  });

  final bool enabled;
  final String label;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final iconSize = clampDouble(screenWidth * 0.036, 14.0, 16.0);
    // Square-shaped tactical button squircle
    final buttonRadius = clampDouble(screenWidth * 0.025, 8.0, 10.0);

    return Material(
      color: enabled ? AppColors.primaryEmerald : AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(buttonRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: clampDouble(screenWidth * 0.030, 10.0, 16.0),
            vertical: clampDouble(screenWidth * 0.025, 10.0, 14.0),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(buttonRadius),
            border: Border.all(
              color: enabled ? AppColors.primaryEmerald : AppColors.surfaceBorder,
              width: 1.0,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.28),
                      blurRadius: 10.0,
                      offset: const Offset(0.0, 3.0),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: enabled ? AppColors.textWhite : AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(width: clampDouble(screenWidth * 0.012, 4.0, 6.0)),
                Icon(
                  LucideIcons.send,
                  size: iconSize,
                  color: enabled ? AppColors.textWhite : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
