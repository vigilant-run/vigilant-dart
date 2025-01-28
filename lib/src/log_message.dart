import 'log_level.dart';

// Represents a single log message.
class LogMessage {
  final DateTime timestamp;
  final String body;
  final Map<String, String> attributes;
  final LogLevel level;

  LogMessage({
    required this.timestamp,
    required this.body,
    required this.attributes,
    required this.level,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'body': body,
        'level': level.name.toUpperCase(),
        'attributes': attributes,
      };
}

// Represents the type of the message (e.g., "logs").
enum MessageType {
  logs,
}

// Represents a batch of log messages to be sent to Vigilant.
class MessageBatch {
  final String token;
  final MessageType type;
  final List<LogMessage> logs;

  MessageBatch({
    required this.token,
    required this.type,
    required this.logs,
  });

  Map<String, dynamic> toJson() => {
        'token': token,
        'type': type.name,
        'logs': logs.map((e) => e.toJson()).toList(),
      };
}
