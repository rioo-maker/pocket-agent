import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../theme.dart';
import 'providers_screen.dart';

/// Plug-and-play first launch: pick a skin, add first model, go.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final skin = state.skin;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: step == 0 ? _stepSkin(state, skin) : _stepModel(state, skin),
        ),
      ),
    );
  }

  Widget _stepSkin(AppState state, TerminalSkin skin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text('PocketAgent',
            textAlign: TextAlign.center,
            style: skin.mono(color: skin.accent, size: 28, weight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Ton agent de code IA, dans un terminal,\ndans ta poche.',
            textAlign: TextAlign.center,
            style: skin.mono(color: skin.toolText)),
        const SizedBox(height: 40),
        Text('1. Choisis ton style de terminal',
            style: skin.mono(color: skin.userText, size: 15, weight: FontWeight.w600)),
        const SizedBox(height: 16),
        _skinChoice(state, TerminalSkin.claude),
        const SizedBox(height: 12),
        _skinChoice(state, TerminalSkin.opencode),
        const Spacer(),
        ElevatedButton(
          onPressed: () => setState(() => step = 1),
          child: const Text('Continuer'),
        ),
      ],
    );
  }

  Widget _skinChoice(AppState state, TerminalSkin s) {
    final selected = state.skin.id == s.id;
    return GestureDetector(
      onTap: () => state.setSkin(s.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: s.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? s.accent : s.border, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Text(s.promptSymbol,
                style: s.mono(color: s.accent, size: 22, weight: FontWeight.bold)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: s.mono(color: s.userText, size: 15)),
                  Text('echo "hello world"',
                      style: s.mono(color: s.toolText, size: 11)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: s.accent),
          ],
        ),
      ),
    );
  }

  Widget _stepModel(AppState state, TerminalSkin skin) {
    final hasModel = state.routes.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text('2. Connecte ton IA',
            style: skin.mono(color: skin.userText, size: 18, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(
          'Choisis un fournisseur (Ollama Cloud, OpenAI, Anthropic, ou ton API perso), colle ta clé et le nom exact du modèle.\n\nTu peux en ajouter plusieurs : si un modèle tombe (clé épuisée), l\'agent bascule automatiquement sur le suivant.',
          style: skin.mono(color: skin.toolText, size: 12.5),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: skin.accent),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: Icon(Icons.add, color: skin.accent),
          label: Text(
              hasModel
                  ? '${state.routes.length} modèle(s) configuré(s) — en ajouter'
                  : 'Ajouter mon premier modèle',
              style: skin.mono(color: skin.accent)),
          onPressed: () => showAddRouteSheet(context),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: hasModel ? () => state.finishOnboarding() : null,
          child: const Text('C\'est parti !'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => state.finishOnboarding(),
          child: Text('Configurer plus tard',
              style: skin.mono(color: skin.toolText, size: 12)),
        ),
      ],
    );
  }
}
