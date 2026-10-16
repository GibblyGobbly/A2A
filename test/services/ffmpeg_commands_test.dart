import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_converter/models/conversion_options.dart';
import 'package:universal_converter/services/ffmpeg_commands.dart';

const _probe = MediaProbe(
  durationSeconds: 10,
  fileSizeBytes: 10 * 1000 * 1000,
  formatBitrate: 8000000,
  videoBitrate: 7800000,
  audioBitrate: 192000,
  width: 1920,
  height: 1080,
);

List<String> _build(
  String target, {
  ConversionOptions options = const ConversionOptions(),
  String out = 'out.mp4',
}) {
  return FfmpegCommands.build(
    input: 'in file.mp4',
    output: out,
    targetId: target,
    options: options,
    probe: _probe,
  );
}

String _value(List<String> args, String flag) => args[args.indexOf(flag) + 1];

void main() {
  group('FfmpegCommands', () {
    test(
      'every command is multi-threaded and keeps the path as one argument',
      () {
        for (final target in [
          'mp4',
          'hevc',
          'av1',
          'webm',
          'mkv',
          'gif',
          'mp3',
          'm4a',
          'opus',
          'ogg',
          'flac',
          'wav',
        ]) {
          final args = _build(target);
          expect(args, containsAllInOrder(['-threads', '8']), reason: target);
          expect(args, contains('in file.mp4'), reason: target);
        }
      },
    );

    test('audio extraction strips video and maps the first audio stream', () {
      for (final target in FfmpegCommands.audioTargets) {
        final args = _build(target, out: 'out.$target');
        expect(args, contains('-vn'), reason: target);
        expect(args, containsAllInOrder(['-map', '0:a:0']), reason: target);
      }
      expect(
        _value(
          _build(
            'mp3',
            options: const ConversionOptions(audioBitrateKbps: 96),
            out: 'a.mp3',
          ),
          '-b:a',
        ),
        '96k',
      );
    });

    test('mp4 outputs use faststart and AV1 targets the hardware encoder', () {
      expect(_build('mp4'), containsAllInOrder(['-movflags', '+faststart']));
      expect(_value(_build('av1'), '-c:v'), 'libsvtav1');
      expect(_value(_build('hevc'), '-c:v'), 'libx265');
      final fallback = FfmpegCommands.build(
        input: 'in.mp4',
        output: 'out.mp4',
        targetId: 'av1',
        options: const ConversionOptions(),
        probe: _probe,
        encoderOverride: VideoEncoder.h264,
      );
      expect(_value(fallback, '-c:v'), 'libx264');
    });

    test('quality mode caps the bitrate below the source', () {
      final balanced = int.parse(_value(_build('mp4'), '-maxrate'));
      final small = int.parse(
        _value(
          _build(
            'mp4',
            options: const ConversionOptions(videoQuality: VideoQuality.small),
          ),
          '-maxrate',
        ),
      );
      expect(balanced, lessThan(_probe.videoBitrate!));
      expect(small, lessThan(balanced));
    });

    test('downscaling lowers the bitrate cap with the pixel count', () {
      final full = FfmpegCommands.videoBitrateCap(
        _probe,
        const ConversionOptions(),
      )!;
      final at540 = FfmpegCommands.videoBitrateCap(
        _probe,
        const ConversionOptions(maxVideoShortEdge: 540),
      )!;
      expect(at540, closeTo(full / 4, full * 0.01));
    });

    test('target size mode budgets bitrate from size and duration', () {
      const options = ConversionOptions(
        compressionMode: CompressionMode.targetSize,
        targetSizePercent: 40,
      );
      final rates = FfmpegCommands.targetSizeBitrates(_probe, options)!;
      final totalBits = (rates.video + rates.audio) * _probe.durationSeconds;
      expect(totalBits / 8, lessThan(_probe.fileSizeBytes * 0.4));
      expect(totalBits / 8, greaterThan(_probe.fileSizeBytes * 0.35));
      expect(_value(_build('mp4', options: options), '-b:v'), '${rates.video}');
    });
  });

  group('FfmpegCommands on host ffmpeg', () {
    final hasFfmpeg = Process.runSync('which', ['ffmpeg']).exitCode == 0;
    late Directory dir;

    setUpAll(() {
      if (!hasFfmpeg) return;
      dir = Directory.systemTemp.createTempSync('a2a_ffmpeg_');
      // A portrait phone-style clip: landscape pixels with a 90 degree display rotation.
      Process.runSync('ffmpeg', [
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=duration=3:size=640x360:rate=30',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=3:sample_rate=48000',
        '-c:v',
        'libx264',
        '-b:v',
        '6M',
        '-c:a',
        'aac',
        '-b:a',
        '256k',
        '${dir.path}/landscape.mp4',
      ]);
      Process.runSync('ffmpeg', [
        '-y',
        '-display_rotation',
        '90',
        '-i',
        '${dir.path}/landscape.mp4',
        '-c',
        'copy',
        '${dir.path}/phone clip\'s.mp4',
      ]);
      Process.runSync('ffmpeg', [
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=duration=1:size=301x201:rate=10',
        '${dir.path}/odd.gif',
      ]);
      Process.runSync('ffmpeg', [
        '-y',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=2:sample_rate=96000',
        '${dir.path}/hires.flac',
      ]);
    });

    tearDownAll(() {
      if (hasFfmpeg) dir.deleteSync(recursive: true);
    });

    MediaProbe probeFile(String path) {
      final out =
          Process.runSync('ffprobe', [
                '-v',
                'error',
                '-show_entries',
                'format=duration,bit_rate',
                '-of',
                'default=nw=1',
                path,
              ]).stdout
              as String;
      final values = {
        for (final l in out.split('\n').where((l) => l.contains('=')))
          l.split('=')[0]: l.split('=')[1],
      };
      return MediaProbe(
        durationSeconds: double.tryParse(values['duration'] ?? '') ?? 0,
        formatBitrate: int.tryParse(values['bit_rate'] ?? ''),
        fileSizeBytes: File(path).lengthSync(),
        width: 640,
        height: 360,
      );
    }

    void run(
      String input,
      String target,
      String ext, {
      ConversionOptions options = const ConversionOptions(),
    }) {
      final output =
          '${dir.path}/out_${target}_${options.compressionMode.name}.$ext';
      final args = FfmpegCommands.build(
        input: input,
        output: output,
        targetId: target,
        options: options,
        probe: probeFile(input),
      );
      final result = Process.runSync('ffmpeg', args);
      expect(result.exitCode, 0, reason: '$target failed:\n${result.stderr}');
      expect(File(output).lengthSync(), greaterThan(0));
    }

    test('video targets encode a rotated phone clip and shrink it', () {
      final input = '${dir.path}/phone clip\'s.mp4';
      for (final target in ['mp4', 'hevc', 'webm', 'mkv', 'gif']) {
        run(input, target, FfmpegCommands.outputExtension(target));
      }
      final inputSize = File(input).lengthSync();
      expect(
        File('${dir.path}/out_mp4_quality.mp4').lengthSync(),
        lessThan(inputSize),
      );
      expect(
        File('${dir.path}/out_hevc_quality.mp4').lengthSync(),
        lessThan(inputSize),
      );
    }, skip: !hasFfmpeg);

    test('target size lands near the requested ratio', () {
      final input = '${dir.path}/phone clip\'s.mp4';
      const options = ConversionOptions(
        compressionMode: CompressionMode.targetSize,
        targetSizePercent: 30,
      );
      run(input, 'mp4', 'mp4', options: options);
      final ratio =
          File('${dir.path}/out_mp4_targetSize.mp4').lengthSync() /
          File(input).lengthSync();
      expect(ratio, inInclusiveRange(0.15, 0.4));
    }, skip: !hasFfmpeg);

    test('downscale keeps portrait orientation and even dimensions', () {
      final input = '${dir.path}/phone clip\'s.mp4';
      final output = '${dir.path}/scaled.mp4';
      final args = FfmpegCommands.build(
        input: input,
        output: output,
        targetId: 'mp4',
        options: const ConversionOptions(maxVideoShortEdge: 240),
        probe: probeFile(input),
      );
      expect(Process.runSync('ffmpeg', args).exitCode, 0);
      final dims =
          (Process.runSync('ffprobe', [
                    '-v',
                    'error',
                    '-select_streams',
                    'v:0',
                    '-show_entries',
                    'stream=width,height',
                    '-of',
                    'csv=p=0:s=x',
                    output,
                  ]).stdout
                  as String)
              .trim();
      expect(dims, '240x426');
    }, skip: !hasFfmpeg);

    test(
      'AV1 via SVT-AV1 encodes in quality and target size modes',
      () {
        final input = '${dir.path}/phone clip\'s.mp4';
        final probe = probeFile(input);
        for (final options in const [
          ConversionOptions(),
          ConversionOptions(
            compressionMode: CompressionMode.targetSize,
            targetSizePercent: 30,
          ),
        ]) {
          final output = '${dir.path}/av1_${options.compressionMode.name}.mp4';
          final args = FfmpegCommands.build(
            input: input,
            output: output,
            targetId: 'av1',
            options: options,
            probe: probe,
          );
          expect(args, containsAllInOrder(['-c:v', 'libsvtav1']));
          final result = Process.runSync('ffmpeg', args);
          expect(result.exitCode, 0, reason: '${result.stderr}');
          expect(File(output).lengthSync(), lessThan(File(input).lengthSync()));
        }
      },
      skip:
          !hasFfmpeg ||
          !(Process.runSync('ffmpeg', ['-hide_banner', '-encoders']).stdout
                  as String)
              .contains('libsvtav1'),
    );

    test('odd sized GIF converts to H.264', () {
      run('${dir.path}/odd.gif', 'mp4', 'mp4');
    }, skip: !hasFfmpeg);

    test(
      'audio targets encode, including 96 kHz input to MP3 and Opus',
      () {
        for (final target in FfmpegCommands.audioTargets) {
          run('${dir.path}/hires.flac', target, target);
        }
        run('${dir.path}/phone clip\'s.mp4', 'mp3', 'mp3');
      },
      skip: !hasFfmpeg,
    );
  });
}
