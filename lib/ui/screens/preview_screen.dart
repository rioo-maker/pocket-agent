import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme.dart';

/// In-app preview of files produced by the agent: html/sites rendered live,
/// markdown rendered, images shown, other text shown raw.
class PreviewScreen extends StatefulWidget {
  final String path;
  final TerminalSkin skin;
  const PreviewScreen({super.key, required this.path, required this.skin});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  WebViewController? _web;
  String _raw = '';
  bool _isImage = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final p = widget.path.toLowerCase();
    final f = File(widget.path);
    if (p.endsWith('.png') ||
        p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.gif') ||
        p.endsWith('.webp')) {
      setState(() => _isImage = true);
      return;
    }
    if (!f.existsSync()) {
      setState(() => _raw = 'Fichier introuvable: ${widget.path}');
      return;
    }
    final content = f.readAsStringSync();
    if (p.endsWith('.html') || p.endsWith('.htm')) {
      _web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadHtmlString(content);
      setState(() {});
    } else if (p.endsWith('.md') || p.endsWith('.markdown')) {
      _web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadHtmlString(_mdToHtml(content));
      setState(() {});
    } else {
      setState(() => _raw = content);
    }
  }

  String _mdToHtml(String md) {
    final esc = const HtmlEscape().convert(md);
    final body = esc
        .replaceAllMapped(RegExp(r'^### (.*)$', multiLine: true),
            (m) => '<h3>${m[1]}</h3>')
        .replaceAllMapped(RegExp(r'^## (.*)$', multiLine: true),
            (m) => '<h2>${m[1]}</h2>')
        .replaceAllMapped(RegExp(r'^# (.*)$', multiLine: true),
            (m) => '<h1>${m[1]}</h1>')
        .replaceAllMapped(
            RegExp(r'\*\*(.*?)\*\*'), (m) => '<b>${m[1]}</b>')
        .replaceAllMapped(RegExp(r'`(.*?)`'), (m) => '<code>${m[1]}</code>')
        .replaceAll('\n', '<br>');
    return '<html><head><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<style>body{font-family:-apple-system,sans-serif;padding:16px;'
        'background:#1a1915;color:#e8e6df;line-height:1.6}'
        'code{background:#262521;padding:2px 6px;border-radius:4px}'
        'h1,h2,h3{color:#d97757}</style></head><body>$body</body></html>';
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final name = widget.path.split('/').last;
    return Scaffold(
      appBar: AppBar(title: Text(name, style: skin.mono(size: 14))),
      body: _isImage
          ? Center(child: InteractiveViewer(child: Image.file(File(widget.path))))
          : _web != null
              ? WebViewWidget(controller: _web!)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(_raw,
                      style: skin.mono(color: skin.assistantText, size: 12)),
                ),
    );
  }
}
