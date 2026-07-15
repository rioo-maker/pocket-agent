import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';

/// Scheduled tasks (crons) list: created by the user or by the agent itself.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final t = await context.read<AppState>().scheduler.list();
    if (mounted) setState(() => _tasks = t);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final skin = state.skin;
    return Scaffold(
      appBar: AppBar(title: const Text('Taches planifiees')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: skin.accent,
        child: Icon(Icons.add_alarm, color: skin.bg),
        onPressed: () => _addDialog(context),
      ),
      body: _tasks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aucune tache.\n\nCree une tache ici, ou demande a l agent:\n"planifie une tache qui resume mes news chaque matin a 8h".\n\nLes taches tournent quand l app est ouverte et se relancent au demarrage.',
                  textAlign: TextAlign.center,
                  style: skin.mono(color: skin.toolText),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _tasks.length,
              itemBuilder: (_, i) {
                final t = _tasks[i];
                final every = t['everyMinutes'];
                final sub = every != null
                    ? 'toutes les $every min'
                    : 'une fois: ${t['when'] ?? t['nextRun']}';
                return Card(
                  color: skin.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: skin.border),
                  ),
                  child: ListTile(
                    title: Text('${t['title']}',
                        style: skin.mono(color: skin.userText, size: 13)),
                    subtitle: Text('$sub\nprochain: ${t['nextRun']}',
                        style: skin.mono(color: skin.toolText, size: 10)),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: t['enabled'] == true,
                          activeColor: skin.accent,
                          onChanged: (_) async {
                            await state.scheduler.toggle('${t['id']}');
                            _refresh();
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: skin.errorText),
                          onPressed: () async {
                            await state.scheduler.remove('${t['id']}');
                            _refresh();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _addDialog(BuildContext context) async {
    final state = context.read<AppState>();
    final skin = state.skin;
    final titleCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    final everyCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: skin.surface,
        title: Text('Nouvelle tache', style: skin.mono(color: skin.userText, size: 15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: skin.mono(color: skin.userText, size: 12),
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              TextField(
                controller: promptCtrl,
                style: skin.mono(color: skin.userText, size: 12),
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Instruction pour l agent'),
              ),
              TextField(
                controller: everyCtrl,
                keyboardType: TextInputType.number,
                style: skin.mono(color: skin.userText, size: 12),
                decoration:
                    const InputDecoration(labelText: 'Repeter toutes les X minutes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: skin.mono(color: skin.toolText)),
          ),
          TextButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final every = int.tryParse(everyCtrl.text.trim());
              await state.scheduler.add({
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'title': titleCtrl.text.trim(),
                'prompt': promptCtrl.text.trim(),
                'everyMinutes': every,
                'nextRun': DateTime.now()
                    .add(Duration(minutes: every ?? 1))
                    .toIso8601String(),
                'enabled': true,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _refresh();
            },
            child: Text('Creer', style: skin.mono(color: skin.accent)),
          ),
        ],
      ),
    );
  }
}
