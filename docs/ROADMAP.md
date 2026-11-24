# A2A Roadmap

Everything runs on the phone. No feature may need a network connection. Every
third-party library or model is credited on the licenses screen.

Layout rule: open a file first, then see only the tools that work on it,
grouped as Edit, Convert and shrink, Privacy, Details.

## Images

### Step 1: core (done)
- [x] File-first layout: home, workspace per file type, one screen per tool
- [x] Crop with free, 1:1, 4:5, 3:4, 16:9, 9:16
- [x] Rotate and flip, batch
- [x] Resize by exact pixels or percentage, batch
- [x] Compress to an exact size (50 KB, 100 KB, ... or custom), batch
- [x] Remove location and camera data, lossless for JPG, PNG, WEBP
- [x] Photo details: size, pixels, date, camera, location
- [x] Blur, pixelate or black out parts of a photo

### Step 2: look
- [ ] Black and white, sepia, vintage and other filters
- [ ] Brightness, contrast, saturation, warmth
- [ ] Auto-enhance
- [ ] Sharpen
- [ ] Remove grain (FFmpeg nlmeans / hqdn3d)
- [ ] Before and after slider on every edit screen
- [ ] Undo and redo inside the editor
- [ ] Apply the same edit to many photos

### Step 3: formats
- [ ] SVG to PNG / JPG (flutter_svg, MIT)
- [ ] Save as HEIC (Android 10+) and AVIF (bundled SVT-AV1)
- [ ] Open PSD (flattened) and DNG
- [ ] Open and save JPEG XL (libjxl, BSD-3, native build)

### Step 4: on-device AI (MediaPipe, Apache 2.0)
- [ ] Portrait mode: blur the background behind people
- [ ] Remove background (people)
- [ ] Auto-blur faces
- [ ] Smooth skin on portraits

### Step 5: heavy
- [ ] AI upscale 2x / 4x for photos only (Real-ESRGAN + ncnn, BSD-3, Vulkan GPU)
- [ ] Scan a document from a photo: corner drag, straighten, clean black and white
- [ ] Collage and stitch (side by side, stacked screenshots)
- [ ] Square fit with border, watermark, passport photo sizes, images to GIF

## Video and audio
See [VIDEO_PLAN.md](VIDEO_PLAN.md).

## PDF
- [ ] Page organizer with thumbnails: reorder, rotate, delete
- [ ] Split, extract pages
- [ ] Password protect and unlock
- [ ] Page numbers, text watermark

## Performance
- [ ] Native Android fast path for photo crop, rotate and resize
  (hardware JPEG decode); the pure-Dart path stays as the fallback

## Not planned
- High-fidelity DOCX / PPTX to PDF: no open-source on-device engine exists.
  The current text-and-layout conversion stays.
- A full Photopea-style editor with layers and selections: it conflicts with
  keeping the app simple.
- OCR: the good on-device options are proprietary or need a Play Services
  download; revisit with Tesseract (Apache 2.0) later.
