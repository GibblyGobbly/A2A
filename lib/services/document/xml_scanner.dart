/// Minimal streaming scanner for OOXML parts. OOXML is machine-generated and
/// well-formed, so a tag tokenizer is enough and avoids a full XML dependency.
enum XmlTokenType { open, close, selfClosing, text }

class XmlToken {
  final XmlTokenType type;

  /// Qualified tag name such as `w:p`. Empty for text tokens.
  final String name;
  final Map<String, String> attributes;

  /// Decoded text for text tokens.
  final String text;

  const XmlToken(
    this.type, {
    this.name = '',
    this.attributes = const {},
    this.text = '',
  });

  bool get isStart =>
      type == XmlTokenType.open || type == XmlTokenType.selfClosing;
  bool get isEnd =>
      type == XmlTokenType.close || type == XmlTokenType.selfClosing;
}

class XmlScanner {
  static final _token = RegExp(
    r'<(/?)([A-Za-z_][\w:.-]*)((?:\s+[^\s=/>]+\s*=\s*(?:"[^"]*"|'
    "'[^']*'"
    r'))*)\s*(/?)>|<!\[CDATA\[([\s\S]*?)\]\]>|<[?!][\s\S]*?>|([^<]+)',
  );
  static final _attribute = RegExp(
    r'([^\s=]+)\s*=\s*(?:"([^"]*)"|'
    "'([^']*)')",
  );
  static final _entity = RegExp(
    r'&(#x[0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos);',
  );

  static Iterable<XmlToken> scan(String xml) sync* {
    for (final m in _token.allMatches(xml)) {
      final name = m.group(2);
      if (name != null) {
        final closing = m.group(1) == '/';
        final selfClosing = m.group(4) == '/';
        final attrs = <String, String>{};
        final rawAttrs = m.group(3);
        if (rawAttrs != null && rawAttrs.isNotEmpty) {
          for (final a in _attribute.allMatches(rawAttrs)) {
            attrs[a.group(1)!] = decodeEntities(a.group(2) ?? a.group(3) ?? '');
          }
        }
        yield XmlToken(
          closing
              ? XmlTokenType.close
              : (selfClosing ? XmlTokenType.selfClosing : XmlTokenType.open),
          name: name,
          attributes: attrs,
        );
      } else if (m.group(5) != null) {
        yield XmlToken(XmlTokenType.text, text: m.group(5)!);
      } else if (m.group(6) != null) {
        yield XmlToken(XmlTokenType.text, text: decodeEntities(m.group(6)!));
      }
    }
  }

  static String decodeEntities(String input) {
    if (!input.contains('&')) return input;
    return input.replaceAllMapped(_entity, (m) {
      final e = m.group(1)!;
      switch (e) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
      }
      final code = e.startsWith('#x')
          ? int.tryParse(e.substring(2), radix: 16)
          : int.tryParse(e.substring(1));
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });
  }

  static String escape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        // Control characters other than tab, newline and carriage return are invalid in XML 1.0.
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  }

  /// Relationship id to target path, resolved against the folder of [partPath].
  static Map<String, String> parseRelationships(
    String relsXml,
    String partPath,
  ) {
    final baseDir = partPath.contains('/')
        ? partPath.substring(0, partPath.lastIndexOf('/'))
        : '';
    final result = <String, String>{};
    for (final t in scan(relsXml)) {
      if (t.isStart && t.name == 'Relationship') {
        final id = t.attributes['Id'];
        final target = t.attributes['Target'];
        if (id == null ||
            target == null ||
            t.attributes['TargetMode'] == 'External') {
          continue;
        }
        result[id] = resolvePath(baseDir, target);
      }
    }
    return result;
  }

  static String resolvePath(String baseDir, String target) {
    if (target.startsWith('/')) return target.substring(1);
    final parts = baseDir.isEmpty ? <String>[] : baseDir.split('/');
    for (final segment in target.split('/')) {
      if (segment == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (segment.isNotEmpty && segment != '.') {
        parts.add(segment);
      }
    }
    return parts.join('/');
  }
}
