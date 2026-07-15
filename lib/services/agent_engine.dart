import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/provider_config.dart';
import 'agent_tools.dart';
import 'llm_client.dart';
import 'session_store.dart';

/// The agentic loop: user message -> model -> tool calls -> results -> model
/// ... until the model answers without tools. Observed by the terminal UI.
class AgentEngine extends ChangeNotifier {
  final LlmClient _client = LlmClient();
  final SessionStore _store = SessionStore();
  final List<ChatMessage> messages = [];
  final List<LlmMessage> _history = [];

  List<ModelRoute> routes = [];
  String workspace = '';
  bool busy = false;
  String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  static const int maxIterations = 25;

  String get systemPrompt => '''
Tu es PocketAgent, un agent de code autonome qui tourne dans un terminal sur un telephone Android.
Tu as acces au systeme de fichiers du telephone via tes outils. Le workspace de travail est: $workspace
Utilise tes outils pour lire, ecrire, modifier des fichiers, executer des commandes shell, appeler des APIs (http_request: GitHub, Vercel...), chercher sur le web, generer des documents (make_document: html, md, pptx, docx, xlsx) et planifier des taches (schedule_task).
Reponds de facon concise, style terminal. Quand tu codes, ecris les fichiers avec write_file au lieu d'afficher le code.
Termine toujours par un court resume de ce que tu as fait.''';

  void newSession() {
    messages.clear();
    _history.clear();
    sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    notifyListeners();
  }

  String get _title {
    final first = messages.where((m) => m.role == MsgRole.user).firstOrNull;
    final t = first?.content ?? 'Session';
    return t.length > 40 ? '${t.substring(0, 40)}...' : t;
  }

  Future<void> persist() async {
    if (messages.isEmpty) return;
    await _store.save(sessionId, {
      'id': sessionId,
      'title': _title,
      'updatedAt': DateTime.now().toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'history': _history.map((m) => m.toJson()).toList(),
    });
  }

  Future<void> loadSession(String id) async {
    final j = await _store.load(id);
    if (j == null) return;
    messages
      ..clear()
      ..addAll((j['messages'] as List? ?? [])
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e))));
    _history
      ..clear()
      ..addAll((j['history'] as List? ?? [])
          .map((e) => LlmMessage.fromJson(Map<String, dynamic>.from(e))));
    sessionId = id;
    notifyListeners();
  }

  Future<void> restoreLast() async {
    final id = await _store.lastSessionId();
    if (id != null) await loadSession(id);
  }

  Future<List<Map<String, dynamic>>> listSessions() => _store.listMeta();

  Future<void> deleteSession(String id) async {
    await _store.delete(id);
    if (id == sessionId) newSession();
    notifyListeners();
  }

  /// Runs the agent headlessly (used by scheduled tasks). Returns final text.
  Future<String> runHeadless(String prompt) async {
    await send(prompt);
    final last = messages.lastWhere((m) => m.role == MsgRole.assistant,
        orElse: () => ChatMessage(role: MsgRole.info, content: ''));
    return last.content;
  }

  Future<void> send(String userText) async {
    if (busy || userText.trim().isEmpty) return;
    busy = true;
    messages.add(ChatMessage(role: MsgRole.user, content: userText));
    notifyListeners();

    if (_history.isEmpty) {
      _history.add(LlmMessage(role: 'system', content: systemPrompt));
    }
    _history.add(LlmMessage(role: 'user', content: userText));

    final tools = AgentTools.definitions();
    final executor = AgentTools(workspace);

    try {
      for (var i = 0; i < maxIterations; i++) {
        final assistantMsg =
            ChatMessage(role: MsgRole.assistant, content: '', streaming: true);
        messages.add(assistantMsg);
        notifyListeners();

        final turn = await _client.complete(
          routes: routes,
          messages: _history,
          tools: tools,
          onDelta: (d) {
            assistantMsg.content += d;
            notifyListeners();
          },
          onRouteSwitch: (route, reason) {
            messages.insert(
                messages.length - 1,
                ChatMessage(
                    role: MsgRole.info,
                    content:
                        '${route.label} indisponible ($reason) - bascule sur le modele suivant...'));
            notifyListeners();
          },
        );
        assistantMsg.streaming = false;
        if (assistantMsg.content.isEmpty && turn.toolCalls.isEmpty) {
          assistantMsg.content = '[reponse vide]';
        }
        if (assistantMsg.content.isEmpty) {
          messages.remove(assistantMsg);
        }
        notifyListeners();

        if (turn.toolCalls.isEmpty) {
          _history.add(LlmMessage(role: 'assistant', content: turn.text));
          break;
        }

        _history.add(LlmMessage(
          role: 'assistant',
          content: turn.text.isEmpty ? null : turn.text,
          toolCalls: turn.toolCalls
              .map((c) => {
                    'id': c.id,
                    'type': 'function',
                    'function': {
                      'name': c.name,
                      'arguments': jsonEncode(c.arguments),
                    },
                  })
              .toList(),
        ));

        for (final call in turn.toolCalls) {
          final argPreview = _preview(call.arguments);
          final toolMsg = ChatMessage(
              role: MsgRole.tool,
              toolName: call.name,
              content: '> ${call.name}($argPreview)');
          messages.add(toolMsg);
          notifyListeners();

          final result = await executor.execute(call.name, call.arguments);
          toolMsg.content += '\n${_truncate(result, 600)}';
          notifyListeners();

          _history.add(LlmMessage(
            role: 'tool',
            content: result,
            toolCallId: call.id,
            name: call.name,
          ));
        }
      }
    } catch (e) {
      messages.add(ChatMessage(role: MsgRole.error, content: 'x $e'));
    } finally {
      for (final m in messages) {
        m.streaming = false;
      }
      busy = false;
      notifyListeners();
      await persist();
    }
  }

  String _preview(Map<String, dynamic> args) {
    final s = args.entries
        .map((e) => '${e.key}: ${_truncate('${e.value}', 40)}')
        .join(', ');
    return _truncate(s, 120);
  }

  String _truncate(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n)}...';
}
