import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressDialog extends StatelessWidget {
  final String statusText;
  final String subText;
  final double? progress;
  final VoidCallback? onCancel;

  const ProgressDialog({
    super.key,
    this.statusText = 'Converting...',
    this.subText = 'Saved in OmniConvert folder',
    this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final hasProgress = progress != null && progress! >= 0.0;
    final percentInt = hasProgress ? (progress! * 100).clamp(0, 100).toInt() : null;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasProgress) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$percentInt%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppTheme.lightBlue,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  ),
                ),
              ] else ...[
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                subText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: AppTheme.errorRed),
                    label: const Text('Cancel Conversion', style: TextStyle(color: AppTheme.errorRed, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onCancel,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
