import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/provider_config.dart';

/// Result of one LLM turn.
class LlmTurn {
  final String text;
  final List<ToolCallRequest> toolCalls;
  LlmTurn({required this.text, required this.toolCalls});
}

class ToolCallRequest {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  ToolCallRequest({required this.id, required this.name, required this.arguments});
}

class LlmException implements Exception {
  final int? statusCode;
  final String message;
  final bool retriableOnOtherRoute;
  LlmException(this.message, {this.statusCode, this.retriableOnOtherRoute = true});
  @override
  String toString() => 'LlmException($statusCode): $message';
}

/// Streams chat completions from OpenAI-compatible or Anthropic-compatible
/// endpoints, with tool calling. Handles multi-route failover: if a route
/// fails (invalid key, quota, server error), tries the next by priority.
class LlmClient {
  final http.Client _http = http.Client();

  /// Runs one turn against the ordered [routes]. Streams text deltas to
  /// [onDelta]. Returns final text + tool calls. [onRouteSwitch] notifies UI.
  Future<LlmTurn> complete({
    required List<ModelRoute> routes,
    required List<LlmMessage> messages,
    required List<Map<String, dynamic>> tools,
    required void Function(String delta) onDelta,
    void Function(ModelRoute route, String reason)? onRouteSwitch,
  }) async {
    final active = routes.where((r) => r.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    if (active.isEmpty) {
      throw LlmException('Aucun modèle configuré. Ajoute un fournisseur dans les réglages.',
          retriableOnOtherRoute: false);
    }
    Object? lastError;
    for (final route in active) {
      try {
        if (route.apiType == ApiType.anthropic) {
          return await _anthropicTurn(route, messages, tools, onDelta);
        }
        return await _openAiTurn(route, messages, tools, onDelta);
      } on LlmException catch (e) {
        lastError = e;
        if (!e.retriableOnOtherRoute) rethrow;
        onRouteSwitch?.call(route, e.message);
      } catch (e) {
        lastError = e;
        onRouteSwitch?.call(route, e.toString());
      }
    }
    throw LlmException('Tous les modèles ont échoué. Dernière erreur: $lastError',
        retriableOnOtherRoute: false);
  }

  // ---------------- OpenAI-compatible ----------------

  Future<LlmTurn> _openAiTurn(
    ModelRoute route,
    List<LlmMessage> messages,
    List<Map<String, dynamic>> tools,
    void Function(String) onDelta,
  ) async {
    final base = route.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/chat/completions');
    final body = <String, dynamic>{
      'model': route.model,
      'messages': messages.map((m) => m.toOpenAi()).toList(),
      'stream': true,
      if (tools.isNotEmpty) 'tools': tools,
    };
    final req = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode(body);
    if (route.apiKey.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer ${route.apiKey}';
    }

    final resp = await _http.send(req).timeout(const Duration(minutes: 5));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final errBody = await resp.stream.bytesToString();
      throw LlmException(_shortErr(errBody), statusCode: resp.statusCode);
    }

    final textBuf = StringBuffer();
    // tool call accumulation: index -> {id, name, argsBuf}
    final toolBufs = <int, Map<String, dynamic>>{};

    await for (final line in resp.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') continue;
      Map<String, dynamic> chunk;
      try {
        chunk = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final choices = chunk['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) continue;
      final delta = (choices[0] as Map<String, dynamic>)['delta']
          as Map<String, dynamic>?;
      if (delta == null) continue;
      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        textBuf.write(content);
        onDelta(content);
      }
      final tcs = delta['tool_calls'] as List<dynamic>?;
      if (tcs != null) {
        for (final tc in tcs) {
          final m = tc as Map<String, dynamic>;
          final idx = (m['index'] as num?)?.toInt() ?? 0;
          final buf = toolBufs.putIfAbsent(
              idx, () => {'id': '', 'name': '', 'args': StringBuffer()});
          if (m['id'] is String) buf['id'] = m['id'];
          final fn = m['function'] as Map<String, dynamic>?;
          if (fn != null) {
            if (fn['name'] is String) buf['name'] = fn['name'];
            if (fn['arguments'] is String) {
              (buf['args'] as StringBuffer).write(fn['arguments']);
            }
          }
        }
      }
    }

    final calls = <ToolCallRequest>[];
    final sorted = toolBufs.keys.toList()..sort();
    for (final idx in sorted) {
      final b = toolBufs[idx]!;
      final rawArgs = (b['args'] as StringBuffer).toString();
      Map<String, dynamic> args;
      try {
        args = rawArgs.isEmpty
            ? {}
            : jsonDecode(rawArgs) as Map<String, dynamic>;
      } catch (_) {
        args = {'_raw': rawArgs};
      }
      final id = (b['id'] as String).isEmpty ? 'call_$idx' : b['id'] as String;
      calls.add(ToolCallRequest(id: id, name: b['name'] as String, arguments: args));
    }
    return LlmTurn(text: textBuf.toString(), toolCalls: calls);
  }

  // ---------------- Anthropic-compatible ----------------

  Future<LlmTurn> _anthropicTurn(
    ModelRoute route,
    List<LlmMessage> messages,
    List<Map<String, dynamic>> tools,
    void Function(String) onDelta,
  ) async {
    final base = route.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/v1/messages');

    String? system;
    final anthMessages = <Map<String, dynamic>>[];
    for (final m in messages) {
      if (m.role == 'system') {
        system = m.content;
      } else if (m.role == 'tool') {
        anthMessages.add({
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': m.toolCallId,
              'content': m.content ?? '',
            }
          ],
        });
      } else if (m.role == 'assistant' && m.toolCalls != null) {
        final content = <Map<String, dynamic>>[];
        if ((m.content ?? '').isNotEmpty) {
          content.add({'type': 'text', 'text': m.content});
        }
        for (final tc in m.toolCalls!) {
          final fn = tc['function'] as Map<String, dynamic>;
          Map<String, dynamic> input;
          try {
            input = jsonDecode(fn['arguments'] as String? ?? '{}')
                as Map<String, dynamic>;
          } catch (_) {
            input = {};
          }
          content.add({
            'type': 'tool_use',
            'id': tc['id'],
            'name': fn['name'],
            'input': input,
          });
        }
        anthMessages.add({'role': 'assistant', 'content': content});
      } else {
        anthMessages.add({'role': m.role, 'content': m.content ?? ''});
      }
    }

    final body = <String, dynamic>{
      'model': route.model,
      'max_tokens': 8192,
      'stream': true,
      'messages': anthMessages,
      if (system != null) 'system': system,
      if (tools.isNotEmpty)
        'tools': tools
            .map((t) => {
                  'name': t['function']['name'],
                  'description': t['function']['description'],
                  'input_schema': t['function']['parameters'],
                })
            .toList(),
    };

    final req = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['anthropic-version'] = '2023-06-01'
      ..body = jsonEncode(body);
    if (route.apiKey.isNotEmpty) {
      req.headers['x-api-key'] = route.apiKey;
      req.headers['Authorization'] = 'Bearer ${route.apiKey}';
    }

    final resp = await _http.send(req).timeout(const Duration(minutes: 5));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final errBody = await resp.stream.bytesToString();
      throw LlmException(_shortErr(errBody), statusCode: resp.statusCode);
    }

    final textBuf = StringBuffer();
    final calls = <ToolCallRequest>[];
    // index -> {id, name, jsonBuf}
    final toolBufs = <int, Map<String, dynamic>>{};

    await for (final line in resp.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      Map<String, dynamic> ev;
      try {
        ev = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final type = ev['type'] as String?;
      if (type == 'content_block_start') {
        final idx = (ev['index'] as num?)?.toInt() ?? 0;
        final block = ev['content_block'] as Map<String, dynamic>?;
        if (block?['type'] == 'tool_use') {
          toolBufs[idx] = {
            'id': block?['id'] ?? 'call_$idx',
            'name': block?['name'] ?? '',
            'json': StringBuffer(),
          };
        }
      } else if (type == 'content_block_delta') {
        final idx = (ev['index'] as num?)?.toInt() ?? 0;
        final delta = ev['delta'] as Map<String, dynamic>?;
        if (delta?['type'] == 'text_delta') {
          final t = delta?['text'] as String? ?? '';
          textBuf.write(t);
          onDelta(t);
        } else if (delta?['type'] == 'input_json_delta') {
          (toolBufs[idx]?['json'] as StringBuffer?)
              ?.write(delta?['partial_json'] ?? '');
        }
      }
    }

    for (final b in toolBufs.values) {
      final raw = (b['json'] as StringBuffer).toString();
      Map<String, dynamic> args;
      try {
        args = raw.isEmpty ? {} : jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        args = {'_raw': raw};
      }
      calls.add(ToolCallRequest(
          id: b['id'] as String, name: b['name'] as String, arguments: args));
    }
    return LlmTurn(text: textBuf.toString(), toolCalls: calls);
  }

  String _shortErr(String body) {
    if (body.length > 400) return body.substring(0, 400);
    return body;
  }
}
