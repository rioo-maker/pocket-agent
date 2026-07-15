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
}
