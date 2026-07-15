import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Two terminal skins: "claude" (dark + coral accent) and
/// "opencode" (pure black minimal). Neutral names in the UI.
class TerminalSkin {
  final String id;
  final String name;
  final Color bg;
  final Color surface;
  final Color accent;
  final Color userText;
  final Color assistantText;
  final Color toolText;
  final Color errorText;
  final Color infoText;
  final Color border;
  final String promptSymbol;

  const TerminalSkin({
    required this.id,
    required this.name,
    required this.bg,
    required this.surface,
    required this.accent,
    required this.userText,
    required this.assistantText,
    required this.toolText,
    required this.errorText,
    required this.infoText,
    required this.border,
    required this.promptSymbol,
  });

  static const claude = TerminalSkin(
    id: 'claude',
    name: 'Corail',
    bg: Color(0xFF1A1915),
    surface: Color(0xFF262521),
    accent: Color(0xFFD97757),
    userText: Color(0xFFF5F4EF),
    assistantText: Color(0xFFE8E6DF),
    toolText: Color(0xFF9C9A92),
    errorText: Color(0xFFE5484D),
    infoText: Color(0xFF8FA3B8),
    border: Color(0xFF3A3833),
    promptSymbol: '>',
  );

  static const opencode = TerminalSkin(
    id: 'opencode',
    name: 'Minimal',
    bg: Color(0xFF0A0A0A),
    surface: Color(0xFF161616),
    accent: Color(0xFFFAB283),
    userText: Color(0xFFEEEEEE),
    assistantText: Color(0xFFDDDDDD),
    toolText: Color(0xFF808080),
    errorText: Color(0xFFFF5C5C),
    infoText: Color(0xFF56B6C2),
    border: Color(0xFF2A2A2A),
    promptSymbol: '❯',
  );

  static TerminalSkin byId(String id) =>
      id == 'opencode' ? opencode : claude;

  TextStyle mono({Color? color, double size = 13.5, FontWeight? weight}) =>
      GoogleFonts.jetBrainsMono(
          color: color ?? assistantText, fontSize: size, fontWeight: weight);

  ThemeData toTheme() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.dark(
          primary: accent,
          surface: surface,
          error: errorText,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          foregroundColor: userText,
          elevation: 0,
          titleTextStyle: mono(color: userText, size: 16, weight: FontWeight.w600),
        ),
        textTheme: TextTheme(bodyMedium: mono()),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: accent),
          ),
          hintStyle: mono(color: toolText),
          labelStyle: mono(color: toolText),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: bg,
            textStyle: mono(weight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      );
}
