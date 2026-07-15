import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../models/chat_message.dart';
import '../../services/agent_engine.dart';
import '../theme.dart';
import 'providers_screen.dart';
import 'settings_screen.dart';

/// Main terminal: message stream + prompt input, styled by the active skin.
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

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
            Text(skin.promptSymbol, style: skin.mono(color: skin.accent, size: 18, weight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('PocketAgent', style: skin.mono(color: skin.userText, size: 16, weight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle session',
            icon: Icon(Icons.add_box_outlined, color: skin.toolText),
            onPressed: engine.busy ? null : () => engine.newSession(),
          ),
          IconButton(
            tooltip: 'Modèles',
            icon: Icon(Icons.memory, color: skin.toolText),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProvidersScreen())),
          ),
          IconButton(
            tooltip: 'Réglages',
            icon: Icon(Icons.settings_outlined, color: skin.toolText),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
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
                    itemBuilder: (_, i) => _messageView(engine.messages[i], skin),
                  ),
          ),
          _inputBar(skin, engine),
        ],
      ),
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
            Text('╭───────────────────╮\n│   PocketAgent     │\n╰───────────────────╯',
                textAlign: TextAlign.center,
                style: skin.mono(color: skin.accent, size: 14)),
            const SizedBox(height: 16),
            Text(
              hasModel
                  ? 'Agent prêt. Workspace:\n${state.workspace}\n\nDemande-moi de coder, lire, modifier des fichiers ou lancer des commandes.'
                  : 'Aucun modèle configuré.\nAjoute un fournisseur via l\'icône ⚙ en haut.',
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.role == MsgRole.user)
            SelectableText('$prefix${m.content}',
                style: skin.mono(color: color, weight: FontWeight.w600))
          else if (m.role == MsgRole.tool)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: skin.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: skin.border),
              ),
              child: SelectableText(m.content,
                  style: skin.mono(color: color, size: 12)),
            )
          else
            SelectableText(
              m.streaming && m.content.isEmpty ? '▋' : m.content + (m.streaming ? ' ▋' : ''),
              style: skin.mono(color: color),
            ),
        ],
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
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: engine.busy ? 'Agent en cours...' : 'Instruction pour l\'agent...',
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
                : IconButton(
                    icon: Icon(Icons.send, color: skin.accent),
                    onPressed: () => _send(engine),
                  ),
          ],
        ),
      ),
    );
  }
}
