// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Asks for a new file name without its extension. Returns the trimmed name,
/// or null when cancelled or unchanged.
Future<String?> showRenameDialog(
  BuildContext context, {
  required String initial,
  required String extension,
}) => showDialog<String>(
  context: context,
  builder: (_) => _RenameDialog(initial: initial, extension: extension),
);

class _RenameDialog extends StatefulWidget {
  final String initial;
  final String extension;

  const _RenameDialog({required this.initial, required this.extension});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  /// Characters Android file names cannot contain.
  static final _invalid = RegExp(r'[\\/:*?"<>|]');

  late final TextEditingController _name =
      TextEditingController(text: widget.initial)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initial.length,
        );

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _value => _name.text.trim();

  String? get _error {
    if (_value.isEmpty) return 'Enter a name.';
    if (_invalid.hasMatch(_value)) {
      return 'Names cannot contain \\ / : * ? " < > |';
    }
    return null;
  }

  void _save() {
    if (_error != null) return;
    Navigator.pop(context, _value == widget.initial ? null : _value);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: Text('RENAME', style: AppTheme.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saved copies will use this name. The original file is not '
            'changed.',
            style: AppTheme.caption,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            style: AppTheme.body,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              suffixText: widget.extension.isEmpty
                  ? null
                  : '.${widget.extension}',
              suffixStyle: AppTheme.caption,
              errorText: _value.isEmpty ? null : error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('CANCEL', style: AppTheme.label),
        ),
        TextButton(
          onPressed: error == null ? _save : null,
          child: Text(
            'SAVE',
            style: AppTheme.label.copyWith(
              color: error == null ? AppTheme.ink : AppTheme.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}
