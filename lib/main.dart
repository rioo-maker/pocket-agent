import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/terminal_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  state.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: state.engine),
      ],
      child: const PocketAgentApp(),
    ),
  );
}

class PocketAgentApp extends StatefulWidget {
  const PocketAgentApp({super.key});

  @override
  State<PocketAgentApp> createState() => _PocketAgentAppState();
}

class _PocketAgentAppState extends State<PocketAgentApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      context.read<AppState>().engine.persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'PocketAgent',
      debugShowCheckedModeBanner: false,
      theme: state.skin.toTheme(),
      home: !state.loaded
          ? Scaffold(
              body: Center(
                  child: CircularProgressIndicator(color: state.skin.accent)))
          : state.onboarded
              ? const TerminalScreen()
              : const OnboardingScreen(),
    );
  }
}
