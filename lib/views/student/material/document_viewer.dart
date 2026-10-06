import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentViewer {
  DocumentViewer._();

  static const Set<String> _officeFormats = {
    'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
  };

  static Future<void> open(
    BuildContext context, {
    required String fileUrl,
    required String format,
  }) async {
    final isOffice = _officeFormats.contains(format.toLowerCase());

    final urlToOpen = isOffice
        ? 'https://docs.google.com/viewer?url=${Uri.encodeComponent(fileUrl)}&embedded=true'
        : fileUrl;

    final uri = Uri.tryParse(urlToOpen);
    final launched =
        uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this file.')),
      );
    }
  }
}