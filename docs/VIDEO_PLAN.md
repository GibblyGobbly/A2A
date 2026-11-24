# Video and Audio Plan

## Engines, fastest first

| Path | What | Used for |
|---|---|---|
| A. Stream copy | FFmpeg copies compressed data, no re-encode | Trim, rotate 90, mute, extract audio, split, join same-format clips, remux |
| B. Hardware encode | `h264_mediacodec` / `hevc_mediacodec` in the bundled FFmpeg | Compress, crop, flip, speed, filters, resize |
| C. Software encode | libx264 / libx265 / SVT-AV1 | "Smallest file" option and fallback when B fails |
| D. Media3 Transformer | GPU zero-copy pipeline (Kotlin) | Only if benchmarks show B is too slow for 4K |

Custom C++ is not used for video: codecs already run in C or in hardware.
C++ (dart:ffi) is reserved for photo pixel work and AI image upscaling.
AI upscaling is for images only, never video.

The bundled FFmpeg (ffmpeg-kit full-gpl 2.2.3) has: mediacodec encoders for
H.264, HEVC, AV1, VP9; vid.stab; nlmeans and hqdn3d; atempo; reverse;
minterpolate; scdet; xfade; drawtext; overlay; subtitles (libass).

## Phase V1: core
- [ ] Shared FFmpeg runner with progress and cancel
- [ ] Video details: codec, size, fps, bitrate, rotation, audio
- [ ] Trim (stream copy; precise mode re-encodes)
- [ ] Rotate 90 / 180 (display matrix, no re-encode)
- [ ] Flip / mirror (hardware encode)
- [ ] Mute (stream copy)
- [ ] Extract audio (stream copy when possible)
- [ ] Extract frames: one frame, every N seconds, all frames, scene changes
- [ ] Hardware encode path for compress, software fallback
- [ ] Preview player (video_player, BSD-3) and thumbnail strip
- [ ] Foreground service so long jobs survive the screen turning off

## Audio
Trim, ringtone, volume, normalize, fade, speed, join, remove silence,
noise reduction, mono or stereo, reverse.

## Phase V2: edit
Crop, speed 0.25x to 4x, frame rate, smooth slow motion, reverse, join,
split, GIF and animated WEBP.

## Phase V3: look
Filters, adjustments, stabilize, denoise, text and watermark, blur region,
music and fades, burn subtitles.

## Phase V4: maybe
Multi-clip timeline with transitions, picture in picture, collage.
