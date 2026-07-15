import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../models/provider_config.dart';

/// Manage model routes: add (preset or custom), reorder by priority
/// (drag & drop), enable/disable, delete. Failover follows this order.
class ProvidersScreen extends StatelessWidget {
  const ProvidersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final skin = state.skin;

    return Scaffold(
      appBar: AppBar(title: const Text('Modèles & clés')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: skin.accent,
        child: Icon(Icons.add, color: skin.bg),
        onPressed: () => showAddRouteSheet(context),
      ),
      body: state.routes.isEmpty
          ? Center(
              child: Text(
                'Aucun modèle.\nAppuie sur + pour ajouter.\n\nOrdre = priorité : si un modèle\néchoue (clé épuisée...), l\'agent\nbascule sur le suivant.',
                textAlign: TextAlign.center,
                style: skin.mono(color: skin.toolText),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: state.routes.length,
              onReorder: (o, n) => state.moveRoute(o, n),
              itemBuilder: (context, i) {
                final r = state.routes[i];
                return Card(
                  key: ValueKey(r.id),
                  color: skin.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: skin.border),
                  ),
                  child: ListTile(
                    leading: Text('${i + 1}',
                        style: skin.mono(
                            color: skin.accent,
                            size: 16,
                            weight: FontWeight.bold)),
                    title: Text(r.label,
                        style: skin.mono(color: skin.userText)),
                    subtitle: Text(
                      '${r.model}\n${r.baseUrl}${r.apiKey.isEmpty ? '' : '  ·  clé ●●●'}',
                      style: skin.mono(color: skin.toolText, size: 11),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: r.enabled,
                          activeColor: skin.accent,
                          onChanged: (_) => state.toggleRoute(r.id),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: skin.errorText),
                          onPressed: () => state.removeRoute(r.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Bottom sheet to add a route from a preset or custom endpoint.
Future<void> showAddRouteSheet(BuildContext context) async {
  final state = context.read<AppState>();
  final skin = state.skin;

  ProviderPreset preset = ProviderPreset.presets.first;
  final urlCtrl = TextEditingController(text: preset.baseUrl);
  final keyCtrl = TextEditingController();
  final modelCtrl = TextEditingController();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: skin.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ajouter un modèle',
                  style: skin.mono(
                      color: skin.userText, size: 16, weight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProviderPreset>(
                value: preset,
                dropdownColor: skin.surface,
                style: skin.mono(color: skin.userText),
                decoration: const InputDecoration(labelText: 'Fournisseur'),
                items: ProviderPreset.presets
                    .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (p) {
                  if (p == null) return;
                  setSheet(() {
                    preset = p;
                    urlCtrl.text = p.baseUrl;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(preset.hint,
                  style: skin.mono(color: skin.infoText, size: 11)),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                style: skin.mono(color: skin.userText),
                decoration: const InputDecoration(
                    labelText: 'Endpoint (base URL)',
                    hintText: 'https://ollama.com/v1'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                obscureText: true,
                style: skin.mono(color: skin.userText),
                decoration: InputDecoration(
                    labelText:
                        'Clé API${preset.needsKey ? '' : ' (optionnelle)'}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                style: skin.mono(color: skin.userText),
                decoration: const InputDecoration(
                    labelText: 'Modèle exact',
                    hintText: 'ex: qwen3.5, kimi-k2.7-code:cloud'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final url = urlCtrl.text.trim();
                  final model = modelCtrl.text.trim();
                  if (url.isEmpty || model.isEmpty) return;
                  await state.addRoute(
                    label: '${preset.name} · $model',
                    apiType: preset.apiType,
                    baseUrl: url,
                    apiKey: keyCtrl.text.trim(),
                    model: model,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Ajouter'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
