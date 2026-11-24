// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_converter/models/video_info.dart';
import 'package:universal_converter/services/video/commands/audio_extract_commands.dart';
import 'package:universal_converter/services/video/commands/edit_commands.dart';
import 'package:universal_converter/services/video/commands/encode_args.dart';
import 'package:universal_converter/services/video/commands/frame_commands.dart';
import 'package:universal_converter/services/video/video_info_parser.dart';

VideoInfo _probe(String path) {
  final out = Process.runSync('ffprobe', [
    '-v',
    'error',
    '-print_format',
    'json',
    '-show_format',
    '-show_streams',
    path,
  ]);
  return VideoInfoParser.parse(jsonDecode(out.stdout as String) as Map);
}

void _ffmpeg(List<String> args) {
  final r = Process.runSync('ffmpeg', args);
  expect(r.exitCode, 0, reason: '${r.stderr}');
}

void main() {
  test('hardware encodes keep the source bitrate within limits', () {
    const info = VideoInfo(durationSeconds: 1, videoBitrate: 120000000);
    final args = EncodeArgs.video(VideoEncoderKind.hardware, info);
    expect(args, containsAllInOrder(['-c:v', 'h264_mediacodec']));
    expect(args[args.indexOf('-b:v') + 1], '50000000');
  });

  test('frame estimates', () {
    expect(
      FrameCommands.estimateCount(FrameMode.all, durationSeconds: 10, fps: 30),
      300,
    );
    expect(
      FrameCommands.estimateCount(
        FrameMode.interval,
        durationSeconds: 10,
        fps: 30,
        everySeconds: 3,
      ),
      4,
    );
  });

  group('on host ffmpeg', () {
    final hasFfmpeg = Process.runSync('which', ['ffmpeg']).exitCode == 0;
    late Directory dir;
    late String clip;
    late String portrait;
    late String mkv;

    setUpAll(() {
      if (!hasFfmpeg) return;
      dir = Directory.systemTemp.createTempSync('a2a_video_');
      clip = '${dir.path}/clip one.mp4';
      _ffmpeg([
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc=size=320x240:rate=25',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:sample_rate=44100',
        '-t',
        '3',
        '-c:v',
        'libx264',
        '-g',
        '25',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-shortest',
        clip,
      ]);
      // How phones store portrait video: landscape frames, rotated on display.
      portrait = '${dir.path}/portrait.mp4';
      _ffmpeg([
        '-y',
        '-display_rotation',
        '-90',
        '-i',
        clip,
        '-c',
        'copy',
        portrait,
      ]);
      mkv = '${dir.path}/opus.mkv';
      _ffmpeg(['-y', '-i', clip, '-c:v', 'copy', '-c:a', 'libopus', mkv]);
    });

    tearDownAll(() {
      if (hasFfmpeg) dir.deleteSync(recursive: true);
    });

    test('parser reads duration, size, fps, codecs and rotation', () {
      final info = _probe(clip);
      expect(info.durationSeconds, closeTo(3, 0.1));
      expect((info.width, info.height), (320, 240));
      expect(info.fps, closeTo(25, 0.01));
      expect(info.videoCodec, 'h264');
      expect(info.audioCodec, 'aac');
      expect(info.rotation, 0);

      final turned = _probe(portrait);
      expect(turned.rotation, 90);
      expect((turned.displayWidth, turned.displayHeight), (240, 320));
    }, skip: !hasFfmpeg);

    test('copy trim cuts without re-encoding', () {
      final out = '${dir.path}/trim.mp4';
      _ffmpeg(
        EditCommands.trimCopy(input: clip, output: out, start: 1, end: 2),
      );
      final info = _probe(out);
      // Copy mode cuts on whole packets, so it may run a little long.
      expect(info.durationSeconds, closeTo(1, 0.25));
      expect(info.videoCodec, 'h264');
    }, skip: !hasFfmpeg);

    test('precise trim is frame exact', () {
      final out = '${dir.path}/precise.mp4';
      _ffmpeg(
        EditCommands.trimPrecise(
          input: clip,
          output: out,
          start: 0.52,
          end: 1.72,
          info: _probe(clip),
          encoder: VideoEncoderKind.software,
        ),
      );
      expect(_probe(out).durationSeconds, closeTo(1.2, 0.08));
    }, skip: !hasFfmpeg);

    test('rotation is rewritten without re-encoding and adds up', () {
      final out = '${dir.path}/rotated.mp4';
      _ffmpeg(
        EditCommands.rotateCopy(
          input: portrait,
          output: out,
          info: _probe(portrait),
          quarterTurns: 1,
        ),
      );
      final info = _probe(out);
      expect(info.rotation, 180);
      expect((info.width, info.height), (320, 240));
    }, skip: !hasFfmpeg);

    test('flip re-encodes upright and keeps the shown shape', () {
      final out = '${dir.path}/flip.mp4';
      _ffmpeg(
        EditCommands.transform(
          input: portrait,
          output: out,
          info: _probe(portrait),
          encoder: VideoEncoderKind.software,
          flipHorizontal: true,
        ),
      );
      final info = _probe(out);
      expect(info.rotation, 0);
      expect((info.width, info.height), (240, 320));
      expect(info.hasAudio, isTrue);
    }, skip: !hasFfmpeg);

    test('mute drops audio and keeps video', () {
      final out = '${dir.path}/mute.mp4';
      _ffmpeg(EditCommands.mute(input: clip, output: out));
      final info = _probe(out);
      expect(info.hasAudio, isFalse);
      expect(info.hasVideo, isTrue);
    }, skip: !hasFfmpeg);

    test('audio is copied out in its own format', () {
      for (final (input, codec, ext) in [
        (clip, 'aac', 'm4a'),
        (mkv, 'opus', 'opus'),
      ]) {
        expect(AudioExtractCommands.extensionFor(codec), ext);
        final out = '${dir.path}/audio.$ext';
        _ffmpeg(
          AudioExtractCommands.build(
            input: input,
            output: out,
            audioCodec: codec,
          ),
        );
        final info = _probe(out);
        expect(info.audioCodec, codec);
        expect(info.hasVideo, isFalse);
      }
    }, skip: !hasFfmpeg);

    test('frames: one, every second and every frame', () {
      final single = '${dir.path}/one.png';
      _ffmpeg(FrameCommands.single(input: clip, output: single, seconds: 1.5));
      expect(File(single).existsSync(), isTrue);

      for (final (mode, expected) in [
        (FrameMode.interval, 3),
        (FrameMode.all, 75),
      ]) {
        final sub = Directory('${dir.path}/${mode.name}')..createSync();
        _ffmpeg(
          FrameCommands.many(
            input: clip,
            outputPattern: FrameCommands.pattern(sub.path, 'clip', 'jpg'),
            mode: mode,
          ),
        );
        expect(sub.listSync().length, expected, reason: mode.name);
      }
    }, skip: !hasFfmpeg);
  });
}
