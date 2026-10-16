import '../models/conversion_options.dart';

/// What FFprobe reported about an input. Bitrates are in bits per second.
class MediaProbe {
  final double durationSeconds;
  final int? formatBitrate;
  final int? videoBitrate;
  final int? audioBitrate;
  final int? width;
  final int? height;
  final bool hasVideo;
  final bool hasAudio;
  final int fileSizeBytes;

  const MediaProbe({
    this.durationSeconds = 0,
    this.fileSizeBytes = 0,
    this.formatBitrate,
    this.videoBitrate,
    this.audioBitrate,
    this.width,
    this.height,
    this.hasVideo = true,
    this.hasAudio = true,
  });

  /// Video bitrate, estimated from the container bitrate when the stream does not report one.
  int? get effectiveVideoBitrate {
    if (videoBitrate != null && videoBitrate! > 0) return videoBitrate;
    if (formatBitrate != null && formatBitrate! > 0) {
      final audio = audioBitrate ?? (hasAudio ? 128000 : 0);
      final estimate = formatBitrate! - audio;
      return estimate > 0 ? estimate : null;
    }
    return null;
  }
}

/// Video encoders the builder can target.
/// [av1Svt] runs in the bundled SVT-AV1 executable, not in ffmpeg-kit.
enum VideoEncoder { h264, hevc, av1Svt, av1Hardware, vp9 }

/// Builds FFmpeg argument lists. Arguments are passed as a list (never a joined
/// string), so file names with spaces, quotes or apostrophes are safe.
class FfmpegCommands {
  static const audioTargets = {'mp3', 'm4a', 'opus', 'ogg', 'flac', 'wav'};
  static const videoTargets = {'mp4', 'hevc', 'av1', 'webm', 'mkv', 'gif'};

  static String outputExtension(String targetId) {
    switch (targetId) {
      case 'hevc':
      case 'av1':
        return 'mp4';
      default:
        return targetId;
    }
  }

  static VideoEncoder? encoderFor(String targetId) {
    switch (targetId) {
      case 'mp4':
      case 'mkv':
        return VideoEncoder.h264;
      case 'hevc':
        return VideoEncoder.hevc;
      case 'av1':
        return VideoEncoder.av1Svt;
      case 'webm':
        return VideoEncoder.vp9;
    }
    return null;
  }

  static int _crf(VideoEncoder encoder, VideoQuality quality) {
    const table = {
      VideoEncoder.h264: [23, 26, 30],
      VideoEncoder.hevc: [25, 28, 32],
      VideoEncoder.vp9: [31, 35, 40],
      VideoEncoder.av1Svt: [30, 36, 44],
      VideoEncoder.av1Hardware: [0, 0, 0],
    };
    return table[encoder]![quality.index];
  }

  /// Fraction of the source video bitrate the output may use at the same resolution.
  static double _bitrateCeiling(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.high:
        return 0.8;
      case VideoQuality.balanced:
        return 0.55;
      case VideoQuality.small:
        return 0.35;
    }
  }

  static int _audioKbpsForVideo(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.high:
        return 160;
      case VideoQuality.balanced:
        return 128;
      case VideoQuality.small:
        return 96;
    }
  }

  /// Scale filter limiting the short edge to [shortEdge] while keeping aspect ratio.
  /// Runs after FFmpeg's auto-rotation, so portrait phone videos are handled correctly.
  static String scaleFilter(int shortEdge) {
    return "scale=w='if(gte(iw,ih),-2,min(iw,$shortEdge))':h='if(gte(iw,ih),min(ih,$shortEdge),-2)'";
  }

  /// Maximum video bitrate in bits per second, or null when the source bitrate is unknown.
  /// Scales with the pixel count when the output is downscaled.
  static int? videoBitrateCap(MediaProbe probe, ConversionOptions options) {
    final source = probe.effectiveVideoBitrate;
    if (source == null) return null;
    var cap = source * _bitrateCeiling(options.videoQuality);
    final w = probe.width;
    final h = probe.height;
    final limit = options.maxVideoShortEdge;
    if (limit != null && w != null && h != null && w > 0 && h > 0) {
      final short = w < h ? w : h;
      if (limit < short) {
        final ratio = limit / short;
        cap *= ratio * ratio;
      }
    }
    final rounded = cap.round();
    return rounded < 150000 ? 150000 : rounded;
  }

  /// Bitrates (bits per second) that make the output about [ConversionOptions.targetSizePercent]
  /// of the input size. Null when duration or size is unknown.
  static ({int video, int audio})? targetSizeBitrates(
    MediaProbe probe,
    ConversionOptions options,
  ) {
    if (probe.durationSeconds <= 0 || probe.fileSizeBytes <= 0) return null;
    // Reserve about 3% of the budget for container overhead.
    final totalBps =
        probe.fileSizeBytes *
        8 *
        options.targetSizePercent /
        100 /
        probe.durationSeconds *
        0.97;
    var audio = 0;
    if (probe.hasAudio) {
      audio = (totalBps * 0.1).round().clamp(48000, 128000);
    }
    final video = (totalBps - audio).round();
    return (video: video < 80000 ? 80000 : video, audio: audio);
  }

  static List<String> build({
    required String input,
    required String output,
    required String targetId,
    required ConversionOptions options,
    required MediaProbe probe,
    VideoEncoder? encoderOverride,
  }) {
    final args = <String>['-y', '-hide_banner', '-i', input];

    if (audioTargets.contains(targetId)) {
      args.addAll(['-map', '0:a:0', '-vn', '-sn', '-dn', '-map_metadata', '0']);
      args.addAll(_audioCodecArgs(targetId, options.audioBitrateKbps));
      args.addAll(['-threads', '8', output]);
      return args;
    }

    if (targetId == 'gif') {
      final width = options.maxVideoShortEdge ?? 480;
      args.addAll([
        '-map',
        '0:v:0',
        '-an',
        '-sn',
        '-dn',
        '-vf',
        "fps=12,scale='min($width,iw)':-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4",
        '-loop',
        '0',
        '-threads',
        '8',
        output,
      ]);
      return args;
    }

    final encoder = encoderOverride ?? encoderFor(targetId);
    if (encoder == null) {
      throw ArgumentError('Unknown media target: $targetId');
    }

    args.addAll([
      '-map',
      '0:v:0',
      '-map',
      '0:a:0?',
      '-sn',
      '-dn',
      '-map_metadata',
      '0',
    ]);
    // 4:2:0 encoders need even dimensions; GIFs and some recordings have odd ones.
    final limit = options.maxVideoShortEdge;
    final filters = [
      if (limit != null) scaleFilter(limit),
      'scale=trunc(iw/2)*2:trunc(ih/2)*2',
    ];
    args.addAll(['-vf', filters.join(',')]);

    final sized = options.usesTargetSize
        ? targetSizeBitrates(probe, options)
        : null;
    final audioKbps = sized != null
        ? (sized.audio / 1000).round()
        : _audioKbpsForVideo(options.videoQuality);
    if (sized != null) {
      args.addAll(_targetSizeVideoArgs(encoder, sized.video));
    } else {
      args.addAll(
        _qualityVideoArgs(encoder, options, videoBitrateCap(probe, options)),
      );
    }

    if (encoder == VideoEncoder.vp9) {
      args.addAll([
        '-c:a',
        'libopus',
        '-b:a',
        '${audioKbps > 48 ? audioKbps - 32 : audioKbps}k',
      ]);
    } else {
      args.addAll(['-c:a', 'aac', '-b:a', '${audioKbps}k']);
    }

    if (output.toLowerCase().endsWith('.mp4')) {
      args.addAll(['-movflags', '+faststart']);
    }
    args.addAll(['-threads', '8', output]);
    return args;
  }

  /// Single-pass average bitrate. Lands within roughly 10% of the requested size.
  static List<String> _targetSizeVideoArgs(VideoEncoder encoder, int bitrate) {
    final maxrate = (bitrate * 1.25).round();
    final bufsize = bitrate * 2;
    switch (encoder) {
      case VideoEncoder.h264:
        return [
          '-c:v',
          'libx264',
          '-preset',
          'veryfast',
          '-b:v',
          '$bitrate',
          '-maxrate',
          '$maxrate',
          '-bufsize',
          '$bufsize',
          '-pix_fmt',
          'yuv420p',
        ];
      case VideoEncoder.hevc:
        return [
          '-c:v',
          'libx265',
          '-preset',
          'superfast',
          '-b:v',
          '$bitrate',
          '-maxrate',
          '$maxrate',
          '-bufsize',
          '$bufsize',
          '-pix_fmt',
          'yuv420p',
          '-tag:v',
          'hvc1',
          '-x265-params',
          'log-level=error',
        ];
      case VideoEncoder.vp9:
        return [
          '-c:v',
          'libvpx-vp9',
          '-b:v',
          '$bitrate',
          '-maxrate',
          '$maxrate',
          '-deadline',
          'realtime',
          '-cpu-used',
          '6',
          '-row-mt',
          '1',
          '-pix_fmt',
          'yuv420p',
        ];
      case VideoEncoder.av1Svt:
        return [
          '-c:v',
          'libsvtav1',
          '-preset',
          '10',
          '-b:v',
          '$bitrate',
          '-maxrate',
          '$maxrate',
          '-pix_fmt',
          'yuv420p',
        ];
      case VideoEncoder.av1Hardware:
        return [
          '-c:v',
          'av1_mediacodec',
          '-b:v',
          '$bitrate',
          '-pix_fmt',
          'nv12',
        ];
    }
  }

  static List<String> _qualityVideoArgs(
    VideoEncoder encoder,
    ConversionOptions options,
    int? cap,
  ) {
    final args = <String>[];
    final crf = _crf(encoder, options.videoQuality);
    switch (encoder) {
      case VideoEncoder.h264:
        args.addAll([
          '-c:v',
          'libx264',
          '-preset',
          'veryfast',
          '-crf',
          '$crf',
          '-pix_fmt',
          'yuv420p',
        ]);
        if (cap != null) {
          args.addAll(['-maxrate', '$cap', '-bufsize', '${cap * 2}']);
        }
        break;
      case VideoEncoder.hevc:
        args.addAll([
          '-c:v',
          'libx265',
          '-preset',
          'superfast',
          '-crf',
          '$crf',
          '-pix_fmt',
          'yuv420p',
          '-tag:v',
          'hvc1',
        ]);
        if (cap != null) {
          args.addAll(['-maxrate', '$cap', '-bufsize', '${cap * 2}']);
        }
        args.addAll(['-x265-params', 'log-level=error']);
        break;
      case VideoEncoder.vp9:
        args.addAll([
          '-c:v',
          'libvpx-vp9',
          '-crf',
          '$crf',
          '-b:v',
          cap != null ? '$cap' : '0',
        ]);
        args.addAll([
          '-deadline',
          'realtime',
          '-cpu-used',
          '6',
          '-row-mt',
          '1',
          '-pix_fmt',
          'yuv420p',
        ]);
        break;
      case VideoEncoder.av1Svt:
        // SVT-AV1 spreads work over every core. Preset 10 encodes 1080p at
        // over 100 fps on current phones; HIGH uses the slower, better preset 8.
        args.addAll([
          '-c:v',
          'libsvtav1',
          '-preset',
          options.videoQuality == VideoQuality.high ? '8' : '10',
          '-crf',
          '$crf',
          '-pix_fmt',
          'yuv420p',
        ]);
        if (cap != null) args.addAll(['-maxrate', '$cap']);
        break;
      case VideoEncoder.av1Hardware:
        // Hardware encoders are bitrate driven. AV1 needs about 30% less than H.264 for
        // the same quality, so target 70% of the ceiling; 2 Mbps when the source is unknown.
        final target = cap != null ? (cap * 0.7).round() : 2000000;
        args.addAll([
          '-c:v',
          'av1_mediacodec',
          '-b:v',
          '$target',
          '-pix_fmt',
          'nv12',
        ]);
        break;
    }

    return args;
  }

  static String _vorbisQuality(int kbps) {
    if (kbps <= 64) return '0';
    if (kbps <= 96) return '2';
    if (kbps <= 128) return '4';
    if (kbps <= 192) return '6';
    if (kbps <= 256) return '8';
    return '9';
  }

  static List<String> _audioCodecArgs(String targetId, int kbps) {
    switch (targetId) {
      case 'mp3':
        return ['-c:a', 'libmp3lame', '-b:a', '${kbps}k'];
      case 'm4a':
        return ['-c:a', 'aac', '-b:a', '${kbps}k', '-movflags', '+faststart'];
      case 'opus':
        return ['-c:a', 'libopus', '-b:a', '${kbps}k'];
      case 'ogg':
        // libvorbis rejects fixed bitrates for some sample rate and channel combinations,
        // so use its VBR quality scale, which approximates the requested bitrate.
        return ['-c:a', 'libvorbis', '-q:a', _vorbisQuality(kbps)];
      case 'flac':
        return ['-c:a', 'flac', '-compression_level', '8'];
      case 'wav':
        return ['-c:a', 'pcm_s16le'];
    }
    throw ArgumentError('Unknown audio target: $targetId');
  }
}
