// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import '../../../models/file_item.dart';
import '../../../models/video_info.dart';
import '../../../services/video/video_info_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/brutal.dart';
import '../../../widgets/info_row.dart';
import '../../../widgets/tool_scaffold.dart';
import '../../../widgets/video/clock_text.dart';

/// Codec, size, frame rate and other details of a video or audio file.
class MediaInfoScreen extends StatefulWidget {
  final FileItem file;

  const MediaInfoScreen({super.key, required this.file});

  @override
  State<MediaInfoScreen> createState() => _MediaInfoScreenState();
}

class _MediaInfoScreenState extends State<MediaInfoScreen> {
  late final Future<VideoInfo> _info = VideoInfoService.read(widget.file.path);

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Details',
      subtitle: widget.file.name,
      children: [
        FutureBuilder<VideoInfo>(
          future: _info,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'Could not read this file: ${snapshot.error}',
                style: AppTheme.body,
              );
            }
            final info = snapshot.data;
            if (info == null) {
              return Center(
                child: CircularProgressIndicator(color: AppTheme.ink),
              );
            }
            return _rows(info);
          },
        ),
      ],
    );
  }

  Widget _rows(VideoInfo i) {
    String kbps(int? bps) => bps == null ? '' : '${(bps / 1000).round()} kbps';
    final rows = [
      InfoRow(
        label: 'Length',
        value: formatClock(i.durationSeconds, tenths: true),
      ),
      InfoRow(label: 'File size', value: widget.file.formattedSize),
      if (i.hasVideo) ...[
        InfoRow(
          label: 'Picture',
          value:
              '${i.displayWidth} x ${i.displayHeight}'
              '${i.rotation != 0 ? ' (stored turned ${i.rotation} deg)' : ''}',
        ),
        if (i.fps != null)
          InfoRow(
            label: 'Frame rate',
            value: '${i.fps!.toStringAsFixed(2)} fps',
          ),
        InfoRow(
          label: 'Video codec',
          value:
              '${i.videoCodec?.toUpperCase() ?? '?'}'
                      '${i.isHdr ? ', HDR' : ''}  ${kbps(i.videoBitrate)}'
                  .trim(),
        ),
      ],
      if (i.hasAudio)
        InfoRow(
          label: 'Audio',
          value: [
            i.audioCodec?.toUpperCase(),
            if (i.audioChannels != null)
              i.audioChannels == 1 ? 'mono' : '${i.audioChannels} channels',
            if (i.audioSampleRate != null) '${i.audioSampleRate} Hz',
          ].whereType<String>().join(', '),
        )
      else
        const InfoRow(label: 'Audio', value: 'None'),
      if (i.bitrate != null) InfoRow(label: 'Bitrate', value: kbps(i.bitrate)),
      if (i.container != null)
        InfoRow(
          label: 'Container',
          value: i.container!.split(',').first.toUpperCase(),
        ),
    ];
    return BrutalBox(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final (n, row) in rows.indexed) ...[
            if (n > 0) const Divider(),
            row,
          ],
        ],
      ),
    );
  }
}
