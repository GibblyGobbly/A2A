/// Which settings panel a target needs.
enum TargetSettings {
  none,
  imageLossy,
  imageLossless,
  imagePdf,
  video,
  gif,
  audioLossy,
}

class ConversionTarget {
  /// Stable identifier used for routing. Usually the output extension, but some
  /// targets share an extension (mp4 vs hevc vs av1) or merge inputs (pdf-merge).
  final String id;
  final String label;

  /// Extension of the written file.
  final String extension;
  final String hint;
  final TargetSettings settings;

  /// True when all selected inputs are combined into a single output file.
  final bool combinesInputs;

  /// Heading the target is listed under, so related outputs sit together.
  final String group;

  const ConversionTarget({
    required this.id,
    required this.label,
    required this.extension,
    required this.hint,
    this.settings = TargetSettings.none,
    this.combinesInputs = false,
    this.group = 'Convert to',
  });

  ConversionTarget inGroup(String group) => ConversionTarget(
    id: id,
    label: label,
    extension: extension,
    hint: hint,
    settings: settings,
    combinesInputs: combinesInputs,
    group: group,
  );

  @override
  bool operator ==(Object other) => other is ConversionTarget && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
