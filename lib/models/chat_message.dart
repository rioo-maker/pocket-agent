/// Roles rendered in the terminal.
enum MsgRole { user, assistant, tool, system, error, info }

class ChatMessage {
  final MsgRole role;
  String content;
  final String? toolName;
  final DateTime time;
  bool streaming;

  ChatMessage({
    required this.role,
    required this.content,
    this.toolName,
    DateTime? time,
    this.streaming = false,
  }) : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        'toolName': toolName,
        'time': time.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: MsgRole.values.firstWhere((r) => r.name == j['role'],
            orElse: () => MsgRole.info),
        content: j['content'] as String? ?? '',
        toolName: j['toolName'] as String?,
        time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Internal message format sent to LLM APIs (OpenAI shape, converted for Anthropic).
class LlmMessage {
  final String role; // system | user | assistant | tool
  final String? content;
  final List<Map<String, dynamic>>? toolCalls; // OpenAI shape
  final String? toolCallId;
  final String? name;

  LlmMessage({
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
    this.name,
  });

  Map<String, dynamic> toOpenAi() {
    final m = <String, dynamic>{'role': role};
    if (content != null) m['content'] = content;
    if (toolCalls != null) m['tool_calls'] = toolCalls;
    if (toolCallId != null) m['tool_call_id'] = toolCallId;
    if (name != null) m['name'] = name;
    return m;
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'toolCalls': toolCalls,
        'toolCallId': toolCallId,
        'name': name,
      };

  factory LlmMessage.fromJson(Map<String, dynamic> j) => LlmMessage(
        role: j['role'] as String? ?? 'user',
        content: j['content'] as String?,
        toolCalls: (j['toolCalls'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        toolCallId: j['toolCallId'] as String?,
        name: j['name'] as String?,
      );
}
