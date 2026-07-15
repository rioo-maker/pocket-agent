import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Tools the agent can call: file system, shell, web fetch.
/// All file paths are resolved inside [workspace] (the agent's sandbox on
/// the phone), unless the user gave an absolute path that exists.
class AgentTools {
  final String workspace;
  AgentTools(this.workspace);

  /// OpenAI-shape tool definitions sent to the model.
  static List<Map<String, dynamic>> definitions() => [
        _def('read_file', 'Lire le contenu d\'un fichier texte.', {
          'path': _s('Chemin du fichier (relatif au workspace ou absolu)'),
        }, [
          'path'
        ]),
        _def('write_file', 'Créer ou écraser un fichier avec du contenu.', {
          'path': _s('Chemin du fichier'),
          'content': _s('Contenu complet à écrire'),
        }, [
          'path',
          'content'
        ]),
        _def('edit_file',
            'Remplacer une chaîne exacte dans un fichier (old_string doit être unique).', {
          'path': _s('Chemin du fichier'),
          'old_string': _s('Texte exact à remplacer'),
          'new_string': _s('Nouveau texte'),
        }, [
          'path',
          'old_string',
          'new_string'
        ]),
        _def('list_dir', 'Lister les fichiers et dossiers d\'un répertoire.', {
          'path': _s('Chemin du dossier (vide = workspace)'),
        }, []),
        _def('run_command',
            'Exécuter une commande shell Android (sh -c). Commandes toybox dispo: ls, cat, grep, find, mkdir, cp, mv, rm, echo...', {
          'command': _s('Commande shell à exécuter'),
        }, [
          'command'
        ]),
        _def('web_fetch', 'Télécharger le contenu texte d\'une URL (GET).', {
          'url': _s('URL complète http(s)'),
        }, [
          'url'
        ]),
        _def('http_request',
            'Requête HTTP complète (méthode, headers, body) pour appeler des APIs: GitHub, Vercel, etc. Ex: créer un repo GitHub, déployer sur Vercel avec un token Authorization.', {
          'method': _s('GET, POST, PUT, PATCH ou DELETE'),
          'url': _s('URL complète https://...'),
          'headers': {
            'type': 'object',
            'description': 'Headers HTTP, ex: {"Authorization": "Bearer TOKEN"}'
          },
          'body': _s('Corps de la requête (JSON ou texte), optionnel'),
        }, [
          'method',
          'url'
        ]),
        _def('search_files',
            'Chercher un motif texte dans les fichiers du workspace (comme grep -r).', {
          'pattern': _s('Texte ou regex à chercher'),
          'path': _s('Sous-dossier optionnel'),
        }, [
          'pattern'
        ]),
      ];

  static Map<String, dynamic> _s(String desc) =>
      {'type': 'string', 'description': desc};

  static Map<String, dynamic> _def(String name, String desc,
          Map<String, dynamic> props, List<String> required) =>
      {
        'type': 'function',
        'function': {
          'name': name,
          'description': desc,
          'parameters': {
            'type': 'object',
            'properties': props,
            'required': required,
          },
        },
      };

  /// Executes a tool call; always returns a string result for the model.
  Future<String> execute(String name, Map<String, dynamic> args) async {
    try {
      switch (name) {
        case 'read_file':
          return _readFile(args['path'] as String? ?? '');
        case 'write_file':
          return _writeFile(
              args['path'] as String? ?? '', args['content'] as String? ?? '');
        case 'edit_file':
          return _editFile(args['path'] as String? ?? '',
              args['old_string'] as String? ?? '', args['new_string'] as String? ?? '');
        case 'list_dir':
          return _listDir(args['path'] as String? ?? '');
        case 'run_command':
          return await _runCommand(args['command'] as String? ?? '');
        case 'web_fetch':
          return await _webFetch(args['url'] as String? ?? '');
        case 'http_request':
          return await _httpRequest(args);
        case 'search_files':
          return _searchFiles(
              args['pattern'] as String? ?? '', args['path'] as String? ?? '');
        default:
          return 'Erreur: outil inconnu "$name"';
      }
    } catch (e) {
      return 'Erreur outil $name: $e';
    }
  }

  String _resolve(String path) {
    if (path.isEmpty) return workspace;
    if (path.startsWith('/')) return path;
    return '$workspace/$path';
  }

  String _readFile(String path) {
    final f = File(_resolve(path));
    if (!f.existsSync()) return 'Erreur: fichier introuvable: $path';
    final content = f.readAsStringSync();
    if (content.length > 60000) {
      return '${content.substring(0, 60000)}\n...[tronqué, fichier de ${content.length} caractères]';
    }
    return content.isEmpty ? '[fichier vide]' : content;
  }

  String _writeFile(String path, String content) {
    final f = File(_resolve(path));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
    return 'OK: ${content.length} caractères écrits dans $path';
  }

  String _editFile(String path, String oldStr, String newStr) {
    final f = File(_resolve(path));
    if (!f.existsSync()) return 'Erreur: fichier introuvable: $path';
    final content = f.readAsStringSync();
    final count = oldStr.allMatches(content).length;
    if (count == 0) return 'Erreur: old_string introuvable dans $path';
    if (count > 1) return 'Erreur: old_string trouvé $count fois, doit être unique';
    f.writeAsStringSync(content.replaceFirst(oldStr, newStr));
    return 'OK: remplacement effectué dans $path';
  }

  String _listDir(String path) {
    final d = Directory(_resolve(path));
    if (!d.existsSync()) return 'Erreur: dossier introuvable: $path';
    final entries = d.listSync()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (entries.isEmpty) return '[dossier vide]';
    return entries.map((e) {
      final name = e.path.split('/').last;
      return e is Directory ? '$name/' : name;
    }).join('\n');
  }

  Future<String> _runCommand(String command) async {
    if (command.trim().isEmpty) return 'Erreur: commande vide';
    final result = await Process.run(
      '/system/bin/sh',
      ['-c', command],
      workingDirectory: workspace,
    ).timeout(const Duration(seconds: 60), onTimeout: () {
      return ProcessResult(0, 124, '', 'Timeout (60s)');
    });
    final out = StringBuffer();
    if ((result.stdout as String).isNotEmpty) out.writeln(result.stdout);
    if ((result.stderr as String).isNotEmpty) {
      out.writeln('[stderr] ${result.stderr}');
    }
    out.write('[exit ${result.exitCode}]');
    final s = out.toString();
    return s.length > 30000 ? '${s.substring(0, 30000)}\n...[tronqué]' : s;
  }

  Future<String> _webFetch(String url) async {
    if (!url.startsWith('http')) return 'Erreur: URL invalide';
    final resp = await http
        .get(Uri.parse(url), headers: {'User-Agent': 'PocketAgent/1.0'})
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode >= 400) {
      return 'Erreur HTTP ${resp.statusCode}';
    }
    var body = utf8.decode(resp.bodyBytes, allowMalformed: true);
    // crude HTML -> text
    if ((resp.headers['content-type'] ?? '').contains('html')) {
      body = body
          .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
    }
    return body.length > 40000 ? '${body.substring(0, 40000)}\n...[tronqué]' : body;
  }

  Future<String> _httpRequest(Map<String, dynamic> args) async {
    final method = (args['method'] as String? ?? 'GET').toUpperCase();
    final url = args['url'] as String? ?? '';
    if (!url.startsWith('http')) return 'Erreur: URL invalide';
    if (!['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].contains(method)) {
      return 'Erreur: méthode $method non supportée';
    }
    final req = http.Request(method, Uri.parse(url));
    req.headers['User-Agent'] = 'PocketAgent/1.0';
    (args['headers'] as Map?)?.forEach((k, v) => req.headers['$k'] = '$v');
    final body = args['body'];
    if (body != null) {
      req.body = body is String ? body : jsonEncode(body);
      req.headers.putIfAbsent('Content-Type', () => 'application/json');
    }
    final resp = await http.Client()
        .send(req)
        .timeout(const Duration(seconds: 60));
    final text = await resp.stream.bytesToString();
    final out = 'HTTP ${resp.statusCode}\n$text';
    return out.length > 40000 ? '${out.substring(0, 40000)}\n...[tronqué]' : out;
  }

  String _searchFiles(String pattern, String sub) {
    final root = Directory(_resolve(sub));
    if (!root.existsSync()) return 'Erreur: dossier introuvable';
    final re = RegExp(pattern, caseSensitive: false);
    final hits = <String>[];
    for (final e in root.listSync(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      if (hits.length >= 100) break;
      try {
        final lines = e.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (re.hasMatch(lines[i])) {
            final rel = e.path.replaceFirst('$workspace/', '');
            hits.add('$rel:${i + 1}: ${lines[i].trim()}');
            if (hits.length >= 100) break;
          }
        }
      } catch (_) {
        // binary or unreadable, skip
      }
    }
    return hits.isEmpty ? 'Aucun résultat' : hits.join('\n');
  }
}
