import 'dart:io';

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
              onTap: () => _editWorkspace(context, state),
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

  Future<void> _editWorkspace(BuildContext context, AppState state) async {
    final skin = state.skin;
    final ctrl = TextEditingController(text: state.workspace);
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: skin.surface,
        title: Text('Dossier workspace',
            style: skin.mono(color: skin.userText, size: 15)),
        content: TextField(
          controller: ctrl,
          style: skin.mono(color: skin.userText, size: 12),
          decoration:
              const InputDecoration(hintText: '/storage/emulated/0/...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: skin.mono(color: skin.toolText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('OK', style: skin.mono(color: skin.accent)),
          ),
        ],
      ),
    );
    if