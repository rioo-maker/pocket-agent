import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../models/chat_message.dart';
import '../../services/agent_engine.dart';
import '../theme.dart';
import 'preview_screen.dart';
import 'providers_screen.dart';
import 'settings_screen.dart';
import 'tasks_screen.dart';

/// Main terminal: message stream + prompt input, styled by the active skin.
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  static const _processText = MethodChannel('pocket_agent/process_text');

  @override
  void initState() {
    super.initState();
    _processText.setMethodCallHandler((call) async {
      if (call.method == 'processText' && call.arguments is String) {
        setState(() => _input.text = call.arguments as String);
      }
    });
    _processText.invokeMethod<String>('getInitialText').then((t) {
      if (t != null && t.isNotEmpty && mounted) {
        setState(() => _input.text = t);
      }
    }).catchError((_) {});
  }

  void _send(AgentEngine engine) {
    final text = _input.text.trim();
    if (text.isEmpty || engine.busy) return;
    _input.clear();
    engine.send(text);
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  String? _previewPath(String content) {
    final m = RegExp(r'\[PREVIEW:([^\]]+)\]').firstMatch(content);
    return m?.group(1);
  }

  Future<void> _showSessions(AgentEngine engine) async {
    final skin = context.read<AppState>().skin;
    final sessions = await engine.listSessions();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: skin.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => sessions.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Aucune conversation sauvegardee.',
                  style: skin.mono(color: skin.toolText)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              shrinkWrap: true,
              itemCount: sessions.length,
              itemBuilder: (_, i) {
                final s = sessions[i];
                return ListTile(
                  leading: Icon(Icons.history, color: skin.accent),
                  title: Text('${s['title']}',
                      style: skin.mono(color: skin.userText, size: 13)),
                  subtitle: Text(
                      '${s['updatedAt']}'.split('.').first.replaceAll('T', ' '),
                      style: skin.mono(color: skin.toolText, size: 10)),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: skin.errorText),
                    onPressed: () async {
                      await engine.deleteSession('${s['id']}');
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  onTap: () async {
                    await engine.loadSession('${s['id']}');
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final engine = context.watch<AgentEngine>();
    final skin = state.skin;
    _autoScroll();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(skin.promptSymbol,
                style: skin.mono(color: skin.accent, size: 18, weight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('PocketAgent',
                style: skin.mono(color: skin.userText, size: 16, weight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Conversations',
            icon: Icon(Icons.history, color: skin.toolText),
            onPressed: engine.busy ? null : () => _showSessions(engine),
          ),
          IconButton(
            tooltip: 'Nouvelle session',
            icon: Icon(Icons.add_box_outlined, color: skin.toolText),
            onPressed: engine.busy ? null : () => engine.newSession(),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: skin.toolText),
            color: skin.surface,
            onSelected: (v) {
              final routes = {
                'models': const ProvidersScreen(),
                'tasks': const TasksScreen(),
                'settings': const SettingsScreen(),
              };
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => routes[v]!));
            },
            itemBuilder: (_) => [
              _menu('models', Icons.memory, 'Modeles & cles', skin),
              _menu('tasks', Icons.alarm, 'Taches planifiees', skin),
              _menu('settings', Icons.settings_outlined, 'Reglages', skin),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: engine.messages.isEmpty
                ? _emptyState(skin, state)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: engine.messages.length,
                    itemBuilder: (_, i) =>
                        _messageView(engine.messages[i], skin),
                  ),
          ),
          _inputBar(skin, engine),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menu(
      String v, IconData icon, String label, TerminalSkin skin) {
    return PopupMenuItem(
      value: v,
      child: Row(children: [
        Icon(icon, color: skin.accent, size: 18),
        const SizedBox(width: 10),
        Text(label, style: skin.mono(color: skin.userText, size: 13)),
      ]),
    );
  }

  Widget _emptyState(TerminalSkin skin, AppState state) {
    final hasModel = state.routes.any((r) => r.enabled);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: skin.accent),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('PocketAgent',
                  style: skin.mono(color: skin.accent, size: 20, weight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            Text(
              hasModel
                  ? 'Agent pret.\n\nDemande-moi de coder, faire un site, lire/editer des fichiers, appeler GitHub/Vercel, ou planifier une tache.'
                  : 'Aucun modele configure.\nMenu ... -> Modeles & cles.',
              textAlign: TextAlign.center,
              style: skin.mono(color: skin.toolText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageView(ChatMessage m, TerminalSkin skin) {
    Color color;
    String prefix;
    switch (m.role) {
      case MsgRole.user:
        color = skin.userText;
        prefix = '${skin.promptSymbol} ';
        break;
      case MsgRole.assistant:
        color = skin.assistantText;
        prefix = '';
        break;
      case MsgRole.tool:
        color = skin.toolText;
        prefix = '';
        break;
      case MsgRole.error:
        color = skin.errorText;
        prefix = '';
        break;
      case MsgRole.info:
      case MsgRole.system:
        color = skin.infoText;
        prefix = '';
        break;
    }

    if (m.role == MsgRole.user) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SelectableText('$prefix${m.content}',
            style: skin.mono(color: color, weight: FontWeight.w600)),
      );
    }

    if (m.role == MsgRole.tool) {
      final preview = _previewPath(m.content);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: skin.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: skin.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(m.content.replaceAll(RegExp(r'\[PREVIEW:[^\]]+\]'), ''),
                  style: skin.mono(color: color, size: 12)),
              if (preview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    icon: Icon(Icons.visibility, size: 16, color: skin.accent),
                    label: Text('Apercu',
                        style: skin.mono(color: skin.accent, size: 12)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              PreviewScreen(path: preview, skin: skin)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SelectableText(
        m.streaming && m.content.isEmpty
            ? '...'
            : m.content + (m.streaming ? ' |' : ''),
        style: skin.mono(color: color),
      ),
    );
  }

  Widget _inputBar(TerminalSkin skin, AgentEngine engine) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: skin.bg,
          border: Border(top: BorderSide(color: skin.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(skin.promptSymbol,
                  style: skin.mono(color: skin.accent, size: 16, weight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _input,
                style: skin.mono(color: skin.userText),
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: engine.busy
                      ? 'Agent en cours...'
                      : 'Instruction pour l agent...',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            engine.busy
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: skin.accent),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: skin.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_upward, color: skin.bg),
                      onPressed: () => _send(engine),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
