# A2A

A2A is an offline file converter and compressor for Android. Images, videos, audio and documents are converted on the phone itself. The app has no servers, no accounts, no analytics and does not even request the internet permission.

## Features

### Images
- Convert between JPG, WEBP, PNG, BMP, GIF and ICO. Reads HEIC, HEIF, AVIF and TIFF as well.
- Compress by quality, or by target size (for example 50% of the original).
- Resize by longest edge (3840, 2560, 1920, 1280, 800 px).
- Same-format compression never saves a file larger than the original.
- Images to PDF, one PDF per image or all images combined into one PDF, with page size (fit image, A4, Letter), orientation and margins. Drag files to set the page order.
- Animated GIF to MP4.

### Video
- MP4 (H.264), MP4 (H.265), MP4 (AV1), WEBM (VP9), MKV and animated GIF.
- AV1 is encoded with SVT-AV1 on all CPU cores (1080p at over 100 fps on a Snapdragon 8 Elite Gen 5). Phones with a hardware AV1 encoder use it first.
- Compress by quality preset (high, balanced, smallest) with a bitrate ceiling below the source, or by target size.
- Resolution limit (1080p, 720p, 480p), correct for portrait phone videos.
- Extract audio to MP3, M4A, FLAC or WAV.

### Audio
- MP3, M4A (AAC), OPUS, OGG (Vorbis), FLAC and WAV, with a bitrate choice for lossy formats.

### Documents
- PDF to DOCX (paragraphs and headings rebuilt from the text layer), TXT, JPG, PNG or PPTX (one slide per page).
- DOCX and PPTX to PDF or TXT, keeping headings, lists, tables and images.
- TXT and Markdown to PDF or DOCX.
- Merge several PDFs into one.

### App
- Swipe between Image, Video, Audio, Docs and Files.
- Share files to A2A from the gallery or any file manager.
- Files tab with search, type filter, swipe to remove with undo, and long-press multi-select to share or delete.
- Settings: light, dark or system theme, haptic feedback, output folder, clearing temporary files and history, credits, license, Terms of Use and Privacy Policy.
- Batch conversion with progress and cancel; partial files are deleted on failure or cancel.

## Storage

Converted files are saved to `Download/OmniConvert` by default, or to a folder chosen in Settings. Android 11 and newer only let apps write directly into folders inside Download or Documents, so A2A checks a chosen folder before accepting it. Original files are never modified.

## Privacy

A2A collects no data. It has no internet permission, so it cannot send anything off the device. Conversion history and settings are stored in the app's private storage only. See the Privacy Policy in Settings.

## How it works

| Area | Engine |
| --- | --- |
| Video and audio | FFmpeg through FFmpegKit (x264, x265, libvpx, LAME, Opus, Vorbis) |
| AV1 | A bundled static FFmpeg build with SVT-AV1, run as a separate process |
| Images | The pure Dart `image` package, in a background isolate |
| PDF output | The `pdf` package, using the phone's system fonts for full Unicode text |
| PDF input and merging | Syncfusion Flutter PDF |
| PDF to images | Android's built-in `PdfRenderer` |
| DOCX and PPTX | Read and written directly as Office Open XML with the `archive` package |

## Building

Requirements: Flutter (Dart 3.12 or newer), Android SDK with API 24 or newer, and the Android NDK to rebuild the AV1 encoder.

```bash
flutter pub get
flutter analyze && flutter test
flutter run
```

Small release build for 64-bit ARM phones, obfuscated and shrunk:

```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi \
  --obfuscate --split-debug-info=build/symbols
```

The AV1 encoder binary (`android/app/src/main/jniLibs/arm64-v8a/libffmpeg_av1.so`) is checked in. To rebuild it from source (SVT-AV1 v4.2.0 and FFmpeg n9.0.2):

```bash
android/native/build_av1_encoder.sh
```

Release builds are currently signed with the debug key. Add your own signing configuration before publishing.

## Project structure

```
lib/
  models/     data types: files, options, results, targets, legal text
  services/   all conversion logic, storage, history, settings
    document/ DOCX, PPTX, PDF and text readers and writers
  theme/      design tokens, light and dark palettes
  views/      screens
  widgets/    reusable widgets
android/native/  build script for the AV1 encoder
test/        unit and widget tests, including real FFmpeg encodes on the host
```

## Credits

A2A is built on these projects. Thank you to everyone who works on them.

| Project | Used for | License |
| --- | --- | --- |
| [Flutter](https://github.com/flutter/flutter) | App framework | BSD-3-Clause |
| [FFmpeg](https://github.com/FFmpeg/FFmpeg) | Video and audio conversion | LGPL-2.1-or-later, GPL parts |
| [FFmpegKit for Flutter](https://github.com/sk3llo/ffmpeg_kit_flutter) | FFmpeg on Android | LGPL-3.0, GPL-3.0 build |
| [SVT-AV1](https://gitlab.com/AOMediaCodec/SVT-AV1) | AV1 encoding | BSD-3-Clause-Clear, AOM Patent License 1.0 |
| [x264](https://code.videolan.org/videolan/x264) | H.264 encoding | GPL-2.0-or-later |
| [x265](https://bitbucket.org/multicoreware/x265_git) | H.265 encoding | GPL-2.0-or-later |
| [libvpx](https://chromium.googlesource.com/webm/libvpx) | VP9 encoding | BSD-3-Clause |
| [LAME](https://lame.sourceforge.io) | MP3 encoding | LGPL-2.0-or-later |
| [Opus](https://github.com/xiph/opus) and [Vorbis](https://github.com/xiph/vorbis) | Opus and Vorbis audio | BSD-3-Clause |
| [image](https://github.com/brendan-duncan/image) | Image decoding and encoding | MIT |
| [pdf](https://github.com/DavBfr/dart_pdf) | Creating PDFs | Apache-2.0 |
| [Syncfusion Flutter PDF](https://github.com/syncfusion/flutter-widgets) | Reading and merging PDFs | Syncfusion Community License (not open source) |
| [archive](https://github.com/brendan-duncan/archive) | DOCX and PPTX files | MIT |
| [file_picker](https://github.com/miguelpruivo/flutter_file_picker) | Choosing files and folders | MIT |
| [share_plus and path_provider](https://github.com/fluttercommunity/plus_plugins) | Sharing and folders | BSD-3-Clause |
| [open_filex](https://github.com/javaherisaber/open_filex) | Opening results | BSD-3-Clause |
| [permission_handler](https://github.com/Baseflow/flutter-permission-handler) | Storage permission on Android 10 and older | MIT |
| [Archivo Black](https://github.com/Omnibus-Type/ArchivoBlack) | Heading font | SIL OFL 1.1 |
| [Space Grotesk](https://github.com/floriankarsten/space-grotesk) | Body font | SIL OFL 1.1 |

Full license texts are in the app under Settings, Open-source credits, and in [assets/licenses](assets/licenses).

## License

A2A is free software under the GNU General Public License v3.0. See [LICENSE](LICENSE).
