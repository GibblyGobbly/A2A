// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A picture file, decoded at screen resolution so large photos stay fast and
/// light on memory. EXIF rotation is applied by the decoder, matching how the
/// editing tools see the image.
class PreviewImage {
  /// Long edge the preview is decoded at.
  static const previewEdge = 1600;

  static ImageProvider provider(String path) => ResizeImage(
    FileImage(File(path)),
    width: previewEdge,
    height: previewEdge,
    policy: ResizeImagePolicy.fit,
  );

  /// Width / height of the image as displayed, or null when it cannot be read.
  static Future<double?> aspectRatio(String path) {
    final completer = Completer<double?>();
    final stream = provider(path).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final ratio = info.image.width / info.image.height;
        info.dispose();
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(ratio);
      },
      onError: (_, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}

/// Shown where a preview cannot be decoded on this phone.
class PreviewUnavailable extends StatelessWidget {
  final String message;

  const PreviewUnavailable({
    super.key,
    this.message = 'This phone cannot show a preview of this format.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.muted,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTheme.caption,
      ),
    );
  }
}

/// Loads the aspect ratio of [path], then builds [builder] with it. Shows a
/// spinner while loading and [PreviewUnavailable] on failure.
class AspectLoader extends StatefulWidget {
  final String path;
  final Widget Function(BuildContext context, double aspectRatio) builder;

  const AspectLoader({super.key, required this.path, required this.builder});

  @override
  State<AspectLoader> createState() => _AspectLoaderState();
}

class _AspectLoaderState extends State<AspectLoader> {
  late Future<double?> _ratio = PreviewImage.aspectRatio(widget.path);

  @override
  void didUpdateWidget(AspectLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _ratio = PreviewImage.aspectRatio(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double?>(
      future: _ratio,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: AppTheme.ink));
        }
        final ratio = snapshot.data;
        if (ratio == null) return const PreviewUnavailable();
        return widget.builder(context, ratio);
      },
    );
  }
}
