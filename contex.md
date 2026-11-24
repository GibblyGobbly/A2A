# A2A Project Context and Architecture

## 1. Executive Summary

A2A (internal package name: `universal_converter`, app brand: OmniConvert / A2A) is a local, offline file converter and media compressor built for Android using Flutter and Dart. All file transformations, media transcoding, image filtering, and document parsing execute entirely on-device without relying on external servers, cloud storage, or third-party web APIs.

The project is released under the GNU General Public License v3.0 (GPLv3).

## 2. Project Ownership and Version Control Standards

- Repository Owner / Author: Bharathsencha
- Author Email: bharathsencha50@gmail.com
- Git Authorship Policy:
  - All git commits and pull requests must be authored strictly under the repository owner's identity (`Bharathsencha <bharathsencha50@gmail.com>`).
  - No AI co-authorship trailers (such as `Co-authored-by: Claude`) or AI session URLs may be inserted into git history.
  - Locked attribution configuration resides in `.claude/settings.json` and `~/.claude/settings.json`:
    ```json
    {
      "attribution": {
        "commit": "",
        "pr": "",
        "sessionUrl": false
      }
    }
    ```
  - Zero emojis are permitted in commit messages, branch names, or tags.

## 3. Core Technical Stack

- Framework: Flutter (SDK 3.x or higher)
- Language: Dart (SDK ^3.12.2)
- Target Operating System: Android (minSdkVersion 24+, targetSdkVersion 34+)
- Native Platform Layer: Android Kotlin (`MainActivity.kt`) communicating over Flutter MethodChannel `com.universal.converter/storage`
- Media Processing Engine: `ffmpeg_kit_flutter_new` (v4.6.7) with `ffprobe_kit`
- Raster Image Engine: `image` (v4.10.1, pure Dart raster image processing)
- Document Parsing and Generation:
  - `syncfusion_flutter_pdf` (v35.1.37): PDF text extraction and document introspection
  - `pdf` (v3.13.1): PDF document assembly, page rendering, layout synthesis
  - `archive` (v4.3.0): Zip encoding/decoding for OpenXML document structures (.docx, .pptx)
- UI and State Components:
  - `google_fonts` (v8.2.1)
  - `flutter_staggered_animations` (v1.1.1)
  - `percent_indicator` (v4.2.5)
  - `file_picker` (v13.1.0)
  - `open_filex` (v4.7.0)
  - `share_plus` (v13.3.1)
  - `permission_handler` (v13.0.2)
  - `path_provider` (v2.1.6)

## 4. Architecture and Codebase Structure

The project adheres to a clean layered architecture with strict separation between presentation, state orchestration, business logic, data models, and platform services.

```
A2A/
├── .claude/
│   └── settings.json                            # Disables AI attribution trailers in commits
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml                  # Storage, media permissions, hardware acceleration
│       └── kotlin/com/universal/converter/
│           └── universal_converter/
│               └── MainActivity.kt              # MethodChannel handler for storage and media scanner
├── lib/
│   ├── main.dart                                # Application entry point, history initialization, UI theme
│   ├── models/
│   │   ├── conversion_options.dart              # User configurable conversion parameters (CRF, bitrate, quality)
│   │   ├── conversion_result.dart               # Result object with execution duration, size deltas, errors
│   │   └── file_item.dart                       # File representation, category detection, size formatting
│   ├── services/
│   │   ├── app_storage_service.dart             # Output path generation, public Download directory bridge
│   │   ├── document_converter_service.dart      # PDF/DOCX/PPTX/TXT text extraction and synthesis
│   │   ├── format_detector.dart                 # Format capability matrix and target suggestions
│   │   ├── history_service.dart                 # Local JSON persistence and history notifier
│   │   ├── image_converter_service.dart         # Pure Dart and FFmpeg fallback image transformations
│   │   └── media_converter_service.dart         # FFmpeg video transcoding, audio extraction, AV1 pipeline
│   ├── theme/
│   │   └── app_theme.dart                       # Design tokens, color palette, typography, component styles
│   ├── views/
│   │   ├── document_studio_screen.dart          # Document-focused conversion interface
│   │   ├── history_screen.dart                  # Past conversion logs, file actions, metrics
│   │   ├── home_screen.dart                     # Root navigation shell with PageView and navigation bar
│   │   ├── image_studio_screen.dart             # Dedicated image processing studio
│   │   ├── media_studio_screen.dart             # Dedicated video and audio studio
│   │   └── universal_convert_screen.dart        # Any-to-any batch conversion screen
│   └── widgets/
│       ├── file_picker_box.dart                 # Drag-and-drop / file selection trigger card
│       ├── format_chips.dart                    # Format selector chip list
│       ├── progress_dialog.dart                 # Modal progress indicator with cancellation support
│       ├── result_dialog.dart                   # Success/failure summary modal with action buttons
│       └── settings_slider_card.dart            # Slider control for quality, resolution, and bitrates
├── pubspec.yaml                                 # Package configuration and dependency declarations
└── README.md                                    # Project description and run instructions
```

## 5. UI/UX Architecture and Anti-Vibe-Coding Standards

A core requirement of A2A is that the interface must look like a high-utility, production-grade native Android mobile utility, completely avoiding the generic "vibe-coded" AI aesthetics generated by default LLM prompts.

### 5.1 Banned Vibe-Coding Aesthetics
- No dark-mode electric neon gradients (purple-to-blue, indigo glows, or blurred circular ambient backdrops).
- No glassmorphic containers, fuzzy frosted glass, or heavy drop shadows.
- No desktop-web landing page tropes (e.g. gigantic marketing hero banners, centered 3-column feature blocks).
- No ungrounded, arbitrary inline colors (e.g. `Colors.purpleAccent`, `Color(0xFF6366F1)`).
- No non-functional decorative badges or fake interactive chips.

### 5.2 Concrete Design System Tokens
All interface widgets consume strictly from `lib/theme/app_theme.dart`:
- Primary Accent: Deep Blue (`Color(0xFF1E40AF)`)
- Secondary Accent: Royal Blue (`Color(0xFF2563EB)`)
- Background Surface: Pure White (`Color(0xFFFFFFFF)`)
- Scaffold Background: Slate Mist (`Color(0xFFF8FAFC)`)
- High-Contrast Text: Slate Dark (`Color(0xFF0F172A)`)
- Muted Supporting Text: Slate Muted (`Color(0xFF64748B)`)
- Card & Container Stroke: Subtle Border (`Color(0xFFE2E8F0)`)
- Success State: Emerald Green (`Color(0xFF059669)`)
- Error State: Crimson Red (`Color(0xFFDC2626)`)

### 5.3 Mobile Native Geometry and Ergonomics
- Elevation: Flat 0dp elevation across all cards and app bars to maintain a modern, crisp utility appearance.
- Borders: Crisp 1px solid stroke (`Color(0xFFE2E8F0)`) with 12dp border radius for cards, 10dp for buttons.
- Touch Targets: Interactive targets must satisfy a minimum height of 48dp for reliable single-hand thumb navigation.
- Spacing: Systematic 8dp spatial rhythm (8dp, 16dp, 24dp padding).
- Typography: Clear, left-aligned Inter font hierarchy with high contrast ratios exceeding WCAG AAA standards.

## 6. Subsystems and Functional Studios

### 6.1 Image Studio (`ImageConverterService`)
- Supported input formats: PNG, JPG, JPEG, WEBP, BMP, GIF, ICO, TIFF, SVG, HEIC, AVIF.
- Supported output formats: JPG, PNG, WEBP, BMP, GIF, ICO, PDF.
- Processing engine:
  - Primary: Pure Dart `image` package.
  - Orientation normalization: `img.bakeOrientation(decoded)` applies EXIF orientation directly into pixel buffers.
  - Alpha channel handling: When converting RGBA images to JPG/JPEG, creates an opaque RGB buffer filled with white and composites the source image over it.
  - Camera fallback: If Dart decoding fails (e.g. unhandled camera raw or modern container), invokes `FFmpegKit` to render a temporary PNG and decodes that buffer.
  - Multi-page / Single-page PDF conversion: Renders memory PNG bytes into A4 page format via `pdf/widgets.dart`.

### 6.2 Media Studio (`MediaConverterService`)
- Supported input formats: MP4, MKV, MOV, WEBM, AVI, FLV, WMV, M4V, 3GP, TS, MP3, WAV, AAC, FLAC, OGG, M4A, OPUS.
- Supported output formats: MP4 (H.264), AV1 (MP4 container via `libaom-av1`), WEBM (VP9), MKV, GIF, MP3, AAC (M4A), WAV, FLAC, OGG.
- Video Transcoding features:
  - Resolution scaling filters: `-vf "scale='min(1920,iw)':-2"` for 1080p, 720p, 480p, 360p while retaining aspect ratio and ensuring even dimensions.
  - Multi-threading optimization: `-threads 8` across commands for multicore Android CPU utilization.
  - Real-time progress tracking: `FFmpegKitConfig.enableStatisticsCallback` computes fraction from current timestamp against probe duration (`FFprobeKit`).
  - Next-gen AV1 pipeline: Encodes via `libaom-av1` with `-cpu-used 8 -row-mt 1 -tiles 2x2` and dynamic bitrate constraints based on source bitrate. If the codec fails or times out on low-end hardware, falls back to `libx264`.
  - Audio extraction: `-vn` flag with codecs `libmp3lame` (MP3), `aac` (AAC), `pcm_s16le` (WAV), `libvorbis` (OGG), `flac` (FLAC).

### 6.3 Document Studio (`DocumentConverterService`)
- Supported formats: PDF, DOCX, PPTX, TXT, MD.
- Conversion pipeline:
  - PDF to Text: Uses `sf.PdfTextExtractor` from `syncfusion_flutter_pdf`.
  - DOCX text extraction: Uses `archive` (`ZipDecoder`) to parse `word/document.xml`, strips XML elements via regular expressions, and decodes UTF-8 strings.
  - Text to PDF: Generates multipage A4 documents using `pdf/widgets.dart` with custom margins and running headers.
  - Text to DOCX: Constructs valid OpenXML zip archive with `[Content_Types].xml`, `_rels/.rels`, and `word/document.xml`.
  - Text to PPTX: Constructs valid OpenXML presentation zip archive with slide relationships and presentation XML.

### 6.4 History Subsystem (`HistoryService`)
- Local storage: JSON-serialized list stored in app documents directory as `conversion_history.json`.
- State synchronization: Exposes a `ValueNotifier<List<ConversionResult>>` to update UI listeners reactively.
- Metrics recorded: Source path, target path, file sizes before and after, reduction percentage, duration in milliseconds, timestamp, success status, and error logs.

## 7. Storage and Platform Integration

- Default Output Path:
  ```
  /storage/emulated/0/Download/OmniConvert/
  ```
- MethodChannel Name: `com.universal.converter/storage`
- Native Methods in `MainActivity.kt`:
  - `getPublicDirectory`: Returns the absolute path to the public Downloads folder under `OmniConvert`.
  - `scanFile`: Invokes `MediaScannerConnection.scanFile` so newly generated pictures and videos appear immediately in Android Gallery and Google Photos.
  - `openFolder`: Fires an `ACTION_VIEW` intent with `resource/folder` mime type, falling back to file chooser intents if no dedicated file manager is installed.

## 8. System Boundaries and Prohibitions (What NOT to Do)

- No Cloud Networking: Do not integrate AWS S3, Firebase, Google Cloud, Supabase, or external transcoding APIs.
- No Mock Stubs in User Flows: Do not leave placeholder functions or empty stubs. All features visible in the UI must have working, local implementations.
- No Direct Unregistered Storage Writes: Never write output files to random filesystem locations without registering them with `AppStorageService` and `notifyMediaScanner`.
- No AI Git Attribution: Never push commits with `Co-authored-by: Claude` or assistant metadata.
- No Emojis: Strictly zero emojis across code, tests, documentation, and user interfaces.
