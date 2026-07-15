import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../theme.dart';

/// Settings: terminal skin (Claude Code / OpenCode) + workspace folder.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final skin = state.skin;

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('INTERFACE',
              style: skin.mono(color: skin.toolText, size: 11)),
          const SizedBox(height: 8),
          _skinCard(context, state, TerminalSkin.claude),
          const SizedBox(height: 8),
          _skinCard(context, state, TerminalSkin.opencode),
          const SizedBox(height: 24),
          Text('WORKSPACE (dossier de travail de l\'agent)',
              style: skin.mono(color: skin.toolText, size: 11)),
          const SizedBox(height: 8),
          Card(
            color: skin.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: skin.border),
            ),
            child: ListTile(
              title: Text(state.workspace,
                  style: skin.mono(color: skin.userText, size: 12)),
              trailing: Icon(Icons.folder_open, color: skin.accent),
              onTap: () async {
                final dir = await FilePicker.platform.getDirectoryPath();
                if (dir != null) await state.setWorkspace(dir);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'L\'agent lit/écrit les fichiers ici. Choisis un dossier accessible (ex: Documents) pour retrouver tes projets depuis un gestionnaire de fichiers.',
            style: skin.mono(color: skin.toolText, size: 11),
          ),
        ],
      ),
    );
  }

  Widget _skinCard(BuildContext context, AppState state, TerminalSkin s) {
    final selected = state.skin.id == s.id;
    return Card(
      color: s.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: selected ? s.accent : state.skin.border,
            width: selected ? 2 : 1),
      ),
      child: ListTile(
        leading: Text(s.promptSymbol,
            style: s.mono(color: s.accent, size: 20, weight: FontWeight.bold)),
        title: Text(s.name, style: s.mono(color: s.userText, size: 14)),
        subtitle: Text('interface style ${s.name.toLowerCase()}',
            style: s.mono(color: s.toolText, size: 11)),
        trailing:
            selected ? Icon(Icons.check_circle, color: s.accent) : null,
        onTap: () => state.setSkin(s.id),
      ),
    );
  }
}
