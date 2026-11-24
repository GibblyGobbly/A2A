// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../../models/file_item.dart';
import '../../../models/image_details.dart';
import '../../../services/image/image_tools_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/brutal.dart';
import '../../../widgets/info_row.dart';
import '../../../widgets/preview_image.dart';
import '../../../widgets/tool_scaffold.dart';
import 'strip_metadata_screen.dart';

class ImageInfoScreen extends StatefulWidget {
  final FileItem file;

  const ImageInfoScreen({super.key, required this.file});

  @override
  State<ImageInfoScreen> createState() => _ImageInfoScreenState();
}

class _ImageInfoScreenState extends State<ImageInfoScreen> {
  late final Future<ImageDetails> _details = ImageToolsService.details(
    widget.file,
  );

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Photo details',
      subtitle: widget.file.name,
      children: [
        SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: AppTheme.radius,
            child: Image(
              image: PreviewImage.provider(widget.file.path),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const PreviewUnavailable(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<ImageDetails>(
          future: _details,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'Could not read this file: ${snapshot.error}',
                style: AppTheme.body,
              );
            }
            final d = snapshot.data;
            if (d == null) {
              return Center(
                child: CircularProgressIndicator(color: AppTheme.ink),
              );
            }
            return _list(d);
          },
        ),
      ],
    );
  }

  Widget _list(ImageDetails d) {
    final w = d.width;
    final h = d.height;
    final mp = d.megapixels;
    final rows = [
      InfoRow(label: 'Format', value: d.format),
      InfoRow(label: 'File size', value: FileItem.formatBytes(d.sizeBytes)),
      if (w != null && h != null)
        InfoRow(
          label: 'Pixels',
          value: '$w x $h${mp == null ? '' : ' (${mp.toStringAsFixed(1)} MP)'}',
        ),
      if (d.takenAt != null) InfoRow(label: 'Taken', value: d.takenAt!),
      if (d.camera != null) InfoRow(label: 'Camera', value: d.camera!),
      InfoRow(
        label: 'Location',
        value: d.hasLocation
            ? '${d.latitude!.toStringAsFixed(5)}, ${d.longitude!.toStringAsFixed(5)}'
            : 'None found',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrutalBox(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final (i, row) in rows.indexed) ...[
                if (i > 0) const Divider(),
                row,
              ],
            ],
          ),
        ),
        if (!d.hasLocation) ...[
          const SizedBox(height: 12),
          Text(
            'Android hides photo locations from apps, so the original in your '
            'gallery may still have one. Files A2A saves never include it.',
            style: AppTheme.caption,
          ),
        ],
        if (d.hasMetadata) ...[
          const SizedBox(height: 16),
          Text(
            d.hasLocation
                ? 'Anyone you send this photo to can see where it was taken.'
                : 'This photo carries hidden camera data.',
            style: AppTheme.body,
          ),
          const SizedBox(height: 12),
          BrutalButton(
            label: 'Remove hidden data',
            icon: Icons.location_off_outlined,
            color: AppTheme.surface,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StripMetadataScreen(files: [widget.file]),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
