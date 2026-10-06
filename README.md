# A2A

A2A is a local, offline file converter mobile application for Android. All conversions and compressions run on-device without external servers.

## Features

- **Images**: Convert between PNG, JPG, WEBP, BMP, and ICO. Convert images to PDF documents. Adjustable compression quality slider.
- **Audio and Video**: Extract audio to MP3, AAC, and WAV. Convert videos to MP4, AV1, and WebM with compression controls and resolution scaling.
- **Documents**: Convert between PDF, DOCX, PPTX, and TXT.
- **File Management**: Save converted files directly to Download/OmniConvert. Automatic media indexing for Gallery and Photos apps.
- **History**: View conversion history, preview thumbnails, open file location, copy path, and share files.
- **Batch Processing**: Convert multiple files with cancel support per item or batch.

## Storage Location

Converted files are saved to:
```
/storage/emulated/0/Download/OmniConvert
```

## Getting Started

### Prerequisites

- Flutter SDK (3.x or higher)
- Android SDK (API 24+)

### Build and Run

```bash
flutter pub get
flutter run
```

### Build APK

```bash
flutter build apk --release
```

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
