// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../models/conversion_result.dart';
import '../services/background_work_service.dart';
import '../services/batch_runner.dart';
import 'progress_dialog.dart';
import 'result_sheet.dart';

/// Shows the progress dialog while [work] runs, then the result sheet. Used by
/// every tool so they all look and cancel the same way.
///
/// With [keepAlive] the job also runs in a foreground service with a progress
/// notification, so it continues when the screen turns off. Use it for jobs
/// that can take minutes, such as video encodes.
Future<void> runTask(
  BuildContext context, {
  required Future<List<ConversionResult>> Function(BatchProgress onProgress)
  work,
  required VoidCallback onCancel,
  String? keepAlive,
}) async {
  final state = ValueNotifier<({double? progress, String status})>((
    progress: null,
    status: 'Starting',
  ));
  var cancelled = false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ProgressDialog(
      state: state,
      onCancel: () {
        cancelled = true;
        state.value = (progress: null, status: 'Cancelling');
        onCancel();
      },
    ),
  );

  if (keepAlive != null) await BackgroundWorkService.start(keepAlive);
  final List<ConversionResult> results;
  try {
    results = await work((progress, status) {
      state.value = (progress: progress, status: status);
      if (keepAlive != null) BackgroundWorkService.update(progress, status);
    });
  } finally {
    if (keepAlive != null) await BackgroundWorkService.stop();
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  state.dispose();
  if (cancelled) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cancelled. Partial files were deleted.')),
    );
    if (results.isEmpty) return;
  }
  await ResultSheet.show(context, results);
}
