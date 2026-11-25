import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A filled button with depth: a tonal gradient fill and a shadow tinted with
/// its own colour.
///
/// `FilledButton` takes a single `backgroundColor` and has no way to accept a
/// gradient, so the fill is painted by this widget and the button itself is made
/// transparent on top of it. Everything else — minimum size, padding, shape,
/// text style, disabled colours, the ink splash — still comes from
/// `filledButtonTheme`, so this stays a themed button rather than a lookalike.
///
/// The shadow is dropped while the button is disabled: a disabled control that
/// still casts a shadow is claiming to be pressable.
///
/// The elevation is drawn by a custom [ShapeDecoration] rather than a [Material]
/// `elevation` on purpose. Material's elevation tints the *surface* to fake
/// height, which is exactly the "tinted elevation" the palette rules out. A
/// shadow under the shape claims the same height without painting anything else.
class DepthButton extends StatelessWidget {
  const DepthButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    const shape = RoundedRectangleBorder(borderRadius: ThrowRadius.button);

    final content = icon == null
        ? child
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon!,
              const SizedBox(width: 8),
              child,
            ],
          );

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: _enabled ? ThrowSurface.controlFill(context) : null,
        color: _enabled ? null : ThrowSurface.disabledFill(context),
        shadows: _enabled ? ThrowSurface.controlShadow(context) : const [],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          // Transparent so the gradient above shows through; the disabled
          // colour still comes from the theme via the shape decoration.
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: shape,
        ),
        child: content,
      ),
    );
  }
}
