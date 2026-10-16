/// Text for the Terms of Use, Privacy Policy and open-source credits.
/// Kept as data so the pages and the first-run screen render the same source.
class LegalSection {
  final String heading;
  final List<String> paragraphs;

  const LegalSection(this.heading, this.paragraphs);
}

class LegalDocument {
  final String title;
  final String effective;
  final List<LegalSection> sections;

  const LegalDocument({
    required this.title,
    required this.effective,
    required this.sections,
  });
}

class OpenSourceComponent {
  final String name;
  final String purpose;
  final String license;
  final String url;

  /// Asset with the full license text, when it is not covered by the
  /// package licenses Flutter collects automatically.
  final String? licenseAsset;

  const OpenSourceComponent({
    required this.name,
    required this.purpose,
    required this.license,
    required this.url,
    this.licenseAsset,
  });
}

class Legal {
  static const repositoryUrl = 'https://github.com/GibblyGobbly/A2A';
  static const issuesUrl = 'https://github.com/GibblyGobbly/A2A/issues';
  static const appLicenseAsset = 'LICENSE';

  static const terms = LegalDocument(
    title: 'Terms of Use',
    effective: 'Version 1, effective 16 October 2026',
    sections: [
      LegalSection('1. Agreement', [
        'By using A2A you agree to these terms. If you do not agree, do not use the app.',
      ]),
      LegalSection('2. What A2A does', [
        'A2A converts, compresses and combines images, videos, audio files and documents. All processing happens on your phone. A2A has no servers and no accounts.',
      ]),
      LegalSection('3. Free software', [
        'A2A is free software released under the GNU General Public License, version 3 (GPLv3). You may use, study, share and modify it under that license. The full license text is in Settings and the source code is published at github.com/GibblyGobbly/A2A.',
        'A2A includes third-party components that keep their own licenses. They are listed under Open-source credits.',
      ]),
      LegalSection('4. Your files and your responsibility', [
        'You are responsible for the files you convert and for having the right to use them. Do not use A2A to infringe copyright or other rights.',
        'A2A never changes or deletes your original files. It writes new files to Download/OmniConvert, or to the folder you choose in Settings. Converted files are only deleted when you choose Delete files in the app.',
      ]),
      LegalSection('5. Results', [
        'Conversion between formats can lose quality, layout or features, for example fonts and exact positioning when converting documents, or detail when compressing images and videos. Check results before deleting the originals.',
      ]),
      LegalSection('6. No warranty', [
        'A2A is provided "as is", without warranty of any kind, express or implied, including fitness for a particular purpose, as set out in sections 15 and 16 of the GPLv3. To the extent permitted by law, the authors are not liable for any loss of data or other damage arising from use of the app.',
      ]),
      LegalSection('7. Changes', [
        'If these terms change, the new version is shown in the app and you will be asked to accept it once before continuing.',
      ]),
      LegalSection('8. Contact', [
        'Questions and bug reports: github.com/GibblyGobbly/A2A/issues',
      ]),
    ],
  );

  static const privacy = LegalDocument(
    title: 'Privacy Policy',
    effective: 'Version 1, effective 16 October 2026',
    sections: [
      LegalSection('Summary', [
        'A2A does not collect, store on any server, sell or share any data about you. There are no accounts, analytics, advertising, crash reporting or tracking of any kind.',
      ]),
      LegalSection('No internet access', [
        'A2A does not request the Android internet permission, so it is technically unable to send anything off your phone. Links in Settings open in your browser, which is a separate app.',
      ]),
      LegalSection('Files you choose', [
        'A2A reads only the files you pick or share to it, and only to convert them. Android gives A2A a temporary copy of each picked file in the app\'s private cache. Copies are removed automatically and you can remove them at any time with Clear temporary files.',
        'Converted files are saved on your phone, in Download/OmniConvert or the folder you choose in Settings.',
      ]),
      LegalSection('Stored on your phone', [
        'A2A keeps a list of your conversions (file names, sizes, folder paths and dates) and your settings in its private storage, so the Files tab can show your history. This never leaves your phone. Clear it with Clear history, or by uninstalling the app.',
      ]),
      LegalSection('Permissions', [
        'On Android 10 and older, A2A asks for storage access so it can save files to the Download folder. Newer Android versions need no permission for this. A2A does not use the camera, microphone, location, contacts or any account.',
      ]),
      LegalSection('Sharing', [
        'Files leave A2A only when you tap Share, through the Android share sheet, to the app you choose.',
      ]),
      LegalSection('Children', [
        'A2A collects no information from anyone, including children.',
      ]),
      LegalSection('Changes and contact', [
        'Changes to this policy are shown in the app. Questions: github.com/GibblyGobbly/A2A/issues',
      ]),
    ],
  );

  static const components = [
    OpenSourceComponent(
      name: 'Flutter',
      purpose: 'App framework',
      license: 'BSD-3-Clause',
      url: 'https://github.com/flutter/flutter',
    ),
    OpenSourceComponent(
      name: 'FFmpeg',
      purpose: 'Video and audio conversion',
      license: 'LGPL-2.1-or-later, with GPL parts',
      url: 'https://github.com/FFmpeg/FFmpeg',
      licenseAsset: 'assets/licenses/FFmpeg-LICENSE.txt',
    ),
    OpenSourceComponent(
      name: 'FFmpegKit for Flutter',
      purpose:
          'FFmpeg on Android, with x264, x265, LAME, Opus, Vorbis, libvpx and libwebp',
      license: 'LGPL-3.0, GPL-3.0 build',
      url: 'https://github.com/sk3llo/ffmpeg_kit_flutter',
    ),
    OpenSourceComponent(
      name: 'SVT-AV1',
      purpose: 'AV1 video encoder',
      license: 'BSD-3-Clause-Clear, AOM Patent License 1.0',
      url: 'https://gitlab.com/AOMediaCodec/SVT-AV1',
      licenseAsset: 'assets/licenses/SVT-AV1-LICENSE.txt',
    ),
    OpenSourceComponent(
      name: 'x264 and x265',
      purpose: 'H.264 and H.265 video encoders',
      license: 'GPL-2.0-or-later',
      url: 'https://code.videolan.org/videolan/x264',
    ),
    OpenSourceComponent(
      name: 'image',
      purpose: 'Image decoding, resizing and encoding',
      license: 'MIT',
      url: 'https://github.com/brendan-duncan/image',
    ),
    OpenSourceComponent(
      name: 'pdf',
      purpose: 'Creating PDF documents',
      license: 'Apache-2.0',
      url: 'https://github.com/DavBfr/dart_pdf',
    ),
    OpenSourceComponent(
      name: 'Syncfusion Flutter PDF',
      purpose: 'Reading PDF text and merging PDFs',
      license: 'Syncfusion Community License (not open source)',
      url: 'https://github.com/syncfusion/flutter-widgets',
    ),
    OpenSourceComponent(
      name: 'archive',
      purpose: 'Reading and writing DOCX and PPTX files',
      license: 'MIT',
      url: 'https://github.com/brendan-duncan/archive',
    ),
    OpenSourceComponent(
      name: 'file_picker',
      purpose: 'Choosing files',
      license: 'MIT',
      url: 'https://github.com/miguelpruivo/flutter_file_picker',
    ),
    OpenSourceComponent(
      name: 'share_plus and path_provider',
      purpose: 'Sharing files and finding folders',
      license: 'BSD-3-Clause',
      url: 'https://github.com/fluttercommunity/plus_plugins',
    ),
    OpenSourceComponent(
      name: 'open_filex',
      purpose: 'Opening converted files',
      license: 'BSD-3-Clause',
      url: 'https://github.com/javaherisaber/open_filex',
    ),
    OpenSourceComponent(
      name: 'permission_handler',
      purpose: 'Storage permission on Android 10 and older',
      license: 'MIT',
      url: 'https://github.com/Baseflow/flutter-permission-handler',
    ),
    OpenSourceComponent(
      name: 'Archivo Black',
      purpose: 'Heading font',
      license: 'SIL Open Font License 1.1',
      url: 'https://github.com/Omnibus-Type/ArchivoBlack',
      licenseAsset: 'assets/licenses/OFL-ArchivoBlack.txt',
    ),
    OpenSourceComponent(
      name: 'Space Grotesk',
      purpose: 'Body font',
      license: 'SIL Open Font License 1.1',
      url: 'https://github.com/floriankarsten/space-grotesk',
      licenseAsset: 'assets/licenses/OFL-SpaceGrotesk.txt',
    ),
  ];
}
