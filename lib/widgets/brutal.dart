import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

/// Haptic ticks that respect the user's setting.
class Haptics {
  static void tap() {
    if (SettingsService.current.haptics) HapticFeedback.lightImpact();
  }

  static void select() {
    if (SettingsService.current.haptics) HapticFeedback.selectionClick();
  }
}

/// Motion is skipped entirely when the user has turned animations off.
Duration motion(BuildContext context, int milliseconds) =>
    MediaQuery.of(context).disableAnimations
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// A flat rounded card with a thin ink outline. [shadow] adds the small hard shadow.
class BrutalBox extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final bool shadow;
  final double stroke;

  const BrutalBox({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.shadow = false,
    this.stroke = AppTheme.stroke,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTheme.surface,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.ink, width: stroke),
        boxShadow: shadow ? AppTheme.hardShadow : null,
      ),
      child: child,
    );
  }
}

/// A tappable rounded block. Raised blocks sink into their shadow when pressed;
/// flat ones shrink slightly.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double stroke;
  final String? semanticLabel;
  final bool raised;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.stroke = AppTheme.stroke,
    this.semanticLabel,
    this.raised = false,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final pressed = _down && enabled;
    final duration = motion(context, 90);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        onTap: enabled
            ? () {
                Haptics.tap();
                widget.onTap!();
              }
            : null,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          transformAlignment: Alignment.center,
          transform: widget.raised
              ? Matrix4.translationValues(
                  pressed ? AppTheme.shadowOffset.dx : 0,
                  pressed ? AppTheme.shadowOffset.dy : 0,
                  0,
                )
              : Matrix4.diagonal3Values(
                  pressed ? 0.97 : 1.0,
                  pressed ? 0.97 : 1.0,
                  1,
                ),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: enabled ? widget.color ?? AppTheme.surface : AppTheme.paper,
            borderRadius: AppTheme.radius,
            border: Border.all(color: AppTheme.ink, width: widget.stroke),
            boxShadow: widget.raised && enabled && !pressed
                ? AppTheme.hardShadow
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Primary action: raised yellow block with an uppercase label.
class BrutalButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// Defaults to the accent colour.
  final Color? color;
  final bool expand;

  const BrutalButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.color,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final fill = color ?? AppTheme.accent;
    final foreground = onPressed == null
        ? AppTheme.inkSoft
        : AppTheme.onColor(fill);
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: foreground),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.label.copyWith(fontSize: 15, color: foreground),
          ),
        ),
      ],
    );
    return Pressable(
      onTap: onPressed,
      color: fill,
      stroke: AppTheme.strokeHeavy,
      raised: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      semanticLabel: label,
      child: content,
    );
  }
}

/// Rounded icon button with an outline; 48 x 48 minimum.
class BrutalIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  const BrutalIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed,
        color: color,
        padding: const EdgeInsets.all(11),
        semanticLabel: tooltip,
        child: Icon(icon, size: 22, color: AppTheme.ink),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: AppTheme.label)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Single-choice chips. The selected chip turns solid black.
class ChoiceRow<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  const ChoiceRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, 140);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          Semantics(
            selected: value == selected,
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (value != selected) {
                  Haptics.select();
                  onSelected(value);
                }
              },
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOut,
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: value == selected ? AppTheme.ink : AppTheme.surface,
                  borderRadius: AppTheme.radiusSmall,
                  border: Border.all(
                    color: AppTheme.ink,
                    width: AppTheme.stroke,
                  ),
                ),
                // Center with width/height factor 1 sizes the chip to its label
                // instead of stretching it across the row.
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    style: AppTheme.label.copyWith(
                      color: value == selected
                          ? AppTheme.surface
                          : AppTheme.ink,
                      letterSpacing: 0.6,
                    ),
                    child: Text(labelOf(value)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A labelled slider with the current value shown in a black tag.
class ValueSlider extends StatelessWidget {
  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String? minHint;
  final String? maxHint;

  const ValueSlider({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.minHint,
    this.maxHint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label.toUpperCase(), style: AppTheme.label)),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.ink,
                borderRadius: AppTheme.radiusSmall,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                valueText,
                style: AppTheme.label.copyWith(
                  color: AppTheme.surface,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        if (minHint != null && maxHint != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minHint!, style: AppTheme.caption),
              Text(maxHint!, style: AppTheme.caption),
            ],
          ),
      ],
    );
  }
}

/// Rounded colour tile holding a black icon, as on the app icon.
class CategoryTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;

  const CategoryTile({
    super.key,
    required this.color,
    required this.icon,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppTheme.radiusSmall,
        border: Border.all(color: AppTheme.ink, width: AppTheme.stroke),
      ),
      child: Icon(icon, color: AppTheme.onColor(color), size: size * 0.5),
    );
  }
}
