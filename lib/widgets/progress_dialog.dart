import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'brutal.dart';

/// Live progress for a running batch. [progress] null shows an indeterminate bar.
class ProgressDialog extends StatelessWidget {
  final ValueNotifier<({double? progress, String status})> state;
  final VoidCallback onCancel;

  const ProgressDialog({
    super.key,
    required this.state,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder(
            valueListenable: state,
            builder: (context, value, _) {
              final progress = value.progress;
              final percent = progress == null
                  ? null
                  : (progress * 100).clamp(0, 100).round();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    percent == null ? 'WORKING' : '$percent%',
                    style: AppTheme.display.copyWith(fontSize: 48),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value.status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border.all(
                        color: AppTheme.ink,
                        width: AppTheme.stroke,
                      ),
                    ),
                    child: progress == null
                        ? LinearProgressIndicator(
                            minHeight: 20,
                            backgroundColor: AppTheme.surface,
                            color: AppTheme.ink,
                          )
                        : TweenAnimationBuilder<double>(
                            tween: Tween(end: progress.clamp(0.0, 1.0)),
                            duration: motion(context, 250),
                            builder: (context, v, _) => FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: v,
                              child: Container(color: AppTheme.ink),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep the app open. Files are processed on this phone.',
                    style: AppTheme.caption,
                  ),
                  const SizedBox(height: 24),
                  BrutalButton(
                    label: 'Cancel',
                    icon: Icons.close,
                    color: AppTheme.surface,
                    onPressed: onCancel,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
