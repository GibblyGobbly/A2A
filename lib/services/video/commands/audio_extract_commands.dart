// SPDX-License-Identifier: GPL-3.0-or-later

/// Pulls the audio track out of a video, without re-encoding when the codec
/// has a matching file type.
class AudioExtractCommands {
  /// File type that holds each codec unchanged.
  static const _copyExtension = {
    'aac': 'm4a',
    'alac': 'm4a',
    'mp3': 'mp3',
    'opus': 'opus',
    'vorbis': 'ogg',
    'flac': 'flac',
  };

  /// Extension the extracted audio gets: the codec's own type when it can be
  /// copied, otherwise M4A (converted to AAC).
  static String extensionFor(String? audioCodec) =>
      _copyExtension[audioCodec] ?? 'm4a';

  static bool canCopy(String? audioCodec) =>
      _copyExtension.containsKey(audioCodec);

  static List<String> build({
    required String input,
    required String output,
    required String? audioCodec,
  }) => [
    '-y',
    '-hide_banner',
    '-i',
    input,
    '-map',
    '0:a:0',
    '-vn',
    '-sn',
    '-dn',
    '-map_metadata',
    '0',
    if (canCopy(audioCodec)) ...[
      '-c:a',
      'copy',
    ] else ...[
      '-c:a',
      'aac',
      '-b:a',
      '192k',
    ],
    if (output.endsWith('.m4a')) ...['-movflags', '+faststart'],
    '-threads',
    '8',
    output,
  ];
}
