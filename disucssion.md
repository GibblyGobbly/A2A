# Architecture Decision Records and Technical Discussions

This document records the architectural decisions, trade-offs, and engineering discussions for the A2A (OmniConvert) project in the MADR (Markdown Architectural Decision Records) format.

---

## Index of Architectural Decisions

- [ADR-0001: 100% On-Device Local Processing vs. Cloud Conversion](#adr-0001-100-on-device-local-processing-vs-cloud-conversion)
- [ADR-0002: AV1 Video Codec Implementation and x264 Fallback Pipeline](#adr-0002-av1-video-codec-implementation-and-x264-fallback-pipeline)
- [ADR-0003: Centralized Public Storage and Native MediaScanner Registration](#adr-0003-centralized-public-storage-and-native-mediascanner-registration)
- [ADR-0004: Pure Dart OpenXML and PDF Synthesis vs. Native C++ Toolchains](#adr-0004-pure-dart-openxml-and-pdf-synthesis-vs-native-c-toolchains)
- [ADR-0005: Sequential Batch Processing vs. Concurrent Worker Pools](#adr-0005-sequential-batch-processing-vs-concurrent-worker-pools)
- [ADR-0006: Rejection of Vibe-Coded Aesthetics in Favor of High-Utility Native Mobile Design](#adr-0006-rejection-of-vibe-coded-aesthetics-in-favor-of-high-utility-native-mobile-design)
- [ADR-0007: Human Git Authorship and Total Suppression of AI Attribution](#adr-0007-human-git-authorship-and-total-suppression-of-ai-attribution)

---

## ADR-0001: 100% On-Device Local Processing vs. Cloud Conversion

- **Status:** Accepted
- **Date:** 2026-10-06

### Context and Problem Statement
File conversion applications commonly offload transcoding to remote cloud servers to circumvent mobile CPU and memory limitations. However, cloud infrastructure introduces data privacy risks, continuous recurring hosting costs, bandwidth consumption, and failure modes when offline.

### Decision Drivers
- Absolute privacy and security for personal photographs and legal documents.
- Continuous operation in airplane mode or low-connectivity environments.
- Zero server maintenance, API fees, or operational subscription costs.

### Considered Options
- Option 1: Hybrid client with cloud fallback for heavy files.
- Option 2: 100% on-device processing using native embedded binaries and Dart libraries.

### Decision Outcome
Chosen Option: Option 2 (100% on-device processing).
- Positive Consequences: Guaranteed user privacy, zero remote server costs, instant processing without network latency.
- Negative Consequences: High computational load on host device during large video encodes; requires careful thread and memory throttling.

---

## ADR-0002: AV1 Video Codec Implementation and x264 Fallback Pipeline

- **Status:** Accepted
- **Date:** 2026-10-06

### Context and Problem Statement
AV1 yields superior compression efficiency over H.264/HEVC, enabling substantial file size reduction. However, software AV1 encoding (`libaom-av1`) on mobile ARM architectures is highly resource-intensive and prone to failure or timeouts on low-end hardware.

### Decision Drivers
- Provide users with next-generation compression where hardware allows.
- Guarantee that conversion always succeeds without unhandled encoder crashes.

### Decision Outcome
Chosen Option: Execute `libaom-av1` with multi-threading flags (`-threads 8 -cpu-used 8 -row-mt 1 -tiles 2x2`) and dynamic bitrate bounding. If the return code indicates failure, immediately catch the error and execute a fallback pass using `libx264` (`preset veryfast`).
- Positive Consequences: High compression on capable devices; zero failed conversions for the end user on less capable chipsets.
- Negative Consequences: Fallback pass incurs a redundant initial attempt duration before restarting under x264.

---

## ADR-0003: Centralized Public Storage and Native MediaScanner Registration

- **Status:** Accepted
- **Date:** 2026-10-06

### Context and Problem Statement
Modern Android scoped storage isolates app directories. If converted files remain inside app-specific storage, users cannot easily access them through third-party file managers, Gallery, or Photos.

### Decision Drivers
- Immediate visibility of converted media in standard Android Gallery apps.
- Intuitive and predictable file storage location for users.

### Decision Outcome
Chosen Option: Centralize output files in `/storage/emulated/0/Download/OmniConvert/`. Immediately after writing, invoke `MediaScannerConnection.scanFile` via the Kotlin MethodChannel.
- Positive Consequences: Files appear in Gallery and Download managers instantaneously without manual device reboots.
- Negative Consequences: Requires `WRITE_EXTERNAL_STORAGE` handling on legacy Android versions and fallback logic for restricted environments.

---

## ADR-0004: Pure Dart OpenXML and PDF Synthesis vs. Native C++ Toolchains

- **Status:** Accepted
- **Date:** 2026-10-06

### Context and Problem Statement
Full office suite rendering (DOCX, PPTX, PDF) typically depends on massive C/C++ binaries (e.g. Poppler, MuPDF, or headless LibreOffice), increasing APK size by 50MB to 150MB.

### Decision Drivers
- Maintain a compact, lightweight APK footprint.
- Minimize binary complexity, NDK cross-compilation issues, and JNI bridge maintenance.

### Decision Outcome
Chosen Option: Use `syncfusion_flutter_pdf` for PDF inspection, `archive` for DOCX/PPTX XML manipulation, and `pdf/widgets.dart` for vector PDF rendering.
- Positive Consequences: Negligible APK overhead, rapid builds, zero NDK compilation overhead.
- Negative Consequences: Conversion is restricted to text and simple paragraphs; complex multi-column layouts, tables, and embedded vector graphics are normalized.

---

## ADR-0005: Sequential Batch Processing vs. Concurrent Worker Pools

- **Status:** Accepted
- **Date:** 2026-10-06

### Context and Problem Statement
Decoding multiple high-resolution camera images simultaneously on the Dart heap can trigger Out-Of-Memory (OOM) fatal crashes on devices with restricted RAM budgets.

### Decision Drivers
- Application stability during multi-file batch operations.
- Predictable memory consumption.

### Decision Outcome
Chosen Option: Execute batch conversions sequentially in a loop, allowing each image buffer to be released and garbage collected before allocating the next item.
- Positive Consequences: Memory ceiling remains constant regardless of the number of selected files.
- Negative Consequences: Batch operations cannot fully saturate multi-threaded capacity for small image conversions.

---

## ADR-0006: Rejection of Vibe-Coded Aesthetics in Favor of High-Utility Native Mobile Design

- **Status:** Accepted
- **Date:** 2026-10-16

### Context and Problem Statement
AI coding models (like Claude) default to generating "vibe-coded" UI patterns: dark-mode neon gradients (electric violet, indigo), glassmorphic blurred surfaces, desktop-web hero landing page blocks, centered marketing typography, arbitrary non-functional decorative chips, and low-contrast text. These patterns look like generic AI prototypes and feel unnatural on a native mobile utility application.

### Decision Drivers
- The application is a serious, daily-driver mobile utility for Android.
- The interface must feel intentional, responsive, high-contrast, tactile, and aligned with Material 3 principles.
- Avoid visual clutter that distracts from conversion progress, file management, and quality control.

### Considered Options
- Option 1: Accept default AI-generated styling and iterative cosmetic prompts.
- Option 2: Enforce a strict anti-vibe-coding design system with banned anti-patterns and fixed design tokens.

### Decision Outcome
Chosen Option: Option 2 (Strict anti-vibe-coding design system).
- Banned Patterns: No neon gradients, no glassmorphism, no web hero sections, no centered headers, no non-functional decorative chips, no arbitrary inline colors.
- Enforced Patterns: Flat surfaces with 0dp elevation, crisp 1px strokes (`0xFFE2E8F0`), WCAG AAA high-contrast slate text, minimum 48dp touch targets, left-aligned functional headers, and disciplined 8dp spatial grids.
- Positive Consequences: Consistent, polished native Android aesthetic that feels designed by a human engineer; high legibility under all lighting conditions; predictable component reuse.
- Negative Consequences: Claude must be explicitly constrained via system prompts and negative instructions to avoid lapsing into default training tropes.

---

## ADR-0007: Human Git Authorship and Total Suppression of AI Attribution

- **Status:** Accepted
- **Date:** 2026-10-16

### Context and Problem Statement
Modern AI coding assistants (including Claude Code) automatically append git commit trailers such as `Co-authored-by: Claude <noreply@anthropic.com>` or include session links in pull request bodies. This pollutes git version history, creates noise in public changelogs, and breaches repository author identity policies.

### Decision Drivers
- Maintain clean, professional git history attributed solely to the repository owner.
- Prevent third-party bot trailers and AI tracking links in public open-source commits.

### Considered Options
- Option 1: Manually amend commits after AI agents run (`git commit --amend`).
- Option 2: Programmatically disable attribution in Claude Code configurations and mandate user identity rules.

### Decision Outcome
Chosen Option: Option 2 (Programmatically disable attribution via `.claude/settings.json` and enforce git identity).
- Settings applied in `~/.claude/settings.json` and `.claude/settings.json`:
  ```json
  {
    "attribution": {
      "commit": "",
      "pr": "",
      "sessionUrl": false
    }
  }
  ```
- All git commits and pushes must use the configured repository identity: `Bharathsencha <bharathsencha50@gmail.com>`.
- Positive Consequences: Pure human git authorship, clean commit logs, zero AI co-authorship metadata.
- Negative Consequences: None.

---

## Future Proposals and RFCs

### RFC-01: Android Foreground Service for Long-Running Transcodes
- Proposal: Implement an Android Foreground Service with an ongoing notification to guarantee transcoding jobs complete even if the user switches apps or the phone screen turns off.

### RFC-02: On-Device OCR with Google ML Kit
- Proposal: Introduce an offline optical character recognition pipeline to extract text from scanned documents and images.
