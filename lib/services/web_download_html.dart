// lib/services/web_download_html.dart

import 'dart:convert';
import 'dart:html' as html;

void downloadJsonOnWeb(String filename, String jsonContent) {
  final bytes = utf8.encode(jsonContent);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
