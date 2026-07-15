import 'dart:convert';

/// API dialect the endpoint speaks.
enum ApiType { openai, anthropic }

/// One usable "route" to a model: endpoint + key + model name + priority.
/// The failover engine walks routes ordered by priority (lower = first).
class ModelRoute {
  String id;
  String label; // display name, e.g. "Ollama Cloud - qwen3.5"
  ApiType apiType;
  String baseUrl; // e.g. https://ollama.com/v1 or http://localhost:11434/v1
  String apiKey; // may be empty for local
  String model; // exact model id, e.g. "qwen3.5" or "kimi-k2.7-code:cloud"
  int priority; // 0 = highest
  bool enabled;

  ModelRoute({
    required this.id,
    required this.label,
    required this.apiType,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.priority = 0,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'apiType': apiType.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'priority': priority,
        'enabled': enabled,
      };

  factory ModelRoute.fromJson(Map<String, dynamic> j) => ModelRoute(
        id: j['id'] as String,
        label: j['label'] as String? ?? '',
        apiType: ApiType.values.firstWhere(
          (t) => t.name == (j['apiType'] ?? 'openai'),
          orElse: () => ApiType.openai,
        ),
        baseUrl: j['baseUrl'] as String? ?? '',
        apiKey: j['apiKey'] as String? ?? '',
        model: j['model'] as String? ?? '',
        priority: (j['priority'] as num?)?.toInt() ?? 0,
        enabled: j['enabled'] as bool? ?? true,
      );

  static String encodeList(List<ModelRoute> routes) =>
      jsonEncode(routes.map((r) => r.toJson()).toList());

  static List<ModelRoute> decodeList(String raw) {
    if (raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ModelRoute.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }
}

/// Built-in provider presets for plug-and-play setup.
class ProviderPreset {
  final String name;
  final String baseUrl;
  final ApiType apiType;
  final bool needsKey;
  final String hint;

  const ProviderPreset({
    required this.name,
    required this.baseUrl,
    required this.apiType,
    required this.needsKey,
    required this.hint,
  });

  static const presets = <ProviderPreset>[
    ProviderPreset(
      name: 'Ollama Cloud',
      baseUrl: 'https://ollama.com/v1',
      apiType: ApiType.openai,
      needsKey: true,
      hint: 'Clé API ollama.com + nom exact du modèle (ex: qwen3.5, kimi-k2.7-code:cloud)',
    ),
    ProviderPreset(
      name: 'Ollama Local (réseau)',
      baseUrl: 'http://localhost:11434/v1',
      apiType: ApiType.openai,
      needsKey: false,
      hint: 'Ollama sur ce téléphone ou ton PC (remplace localhost par l\'IP du PC)',
    ),
    ProviderPreset(
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      apiType: ApiType.openai,
      needsKey: true,
      hint: 'Clé API OpenAI + modèle (ex: gpt-4o)',
    ),
    ProviderPreset(
      name: 'Anthropic',
      baseUrl: 'https://api.anthropic.com',
      apiType: ApiType.anthropic,
      needsKey: true,
      hint: 'Clé API Anthropic + modèle (ex: claude-sonnet-5)',
    ),
    ProviderPreset(
      name: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1',
      apiType: ApiType.openai,
      needsKey: true,
      hint: 'Clé OpenRouter + modèle (ex: anthropic/claude-sonnet-5)',
    ),
    ProviderPreset(
      name: 'API personnalisée (OpenAI-compatible)',
      baseUrl: '',
      apiType: ApiType.openai,
      needsKey: true,
      hint: 'Endpoint /v1 compatible OpenAI + clé + modèle',
    ),
    ProviderPreset(
      name: 'API personnalisée (Anthropic-compatible)',
      baseUrl: '',
      apiType: ApiType.anthropic,
      needsKey: true,
      hint: 'Endpoint compatible API Anthropic + clé + modèle',
    ),
  ];
}
