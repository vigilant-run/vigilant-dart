import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';

import 'log_level.dart';
import 'log_message.dart';

// Logger is used to send logs to the Vigilant platform.
class Logger {
  final String name;
  final String endpoint;
  final String token;
  final bool passthrough;
  final bool insecure;
  final bool noop;

  static const int maxBatchSize = 100;
  static const int batchIntervalMs = 100;

  final _logController = StreamController<LogMessage>.broadcast();
  final List<LogMessage> _logBuffer = [];

  Timer? _batchTimer;
  bool _isShuttingDown = false;
  Completer<void>? _shutdownCompleter;

  // Constructs a new VigilantLogger instance.
  // [name] - The name of your service.
  // [endpoint] - The domain or host of your Vigilant endpoint.
  // [token] - The bearer token used for authentication.
  // [passthrough] - Prints log messages to console if true.
  // [insecure] - Uses http instead of https if true.
  // [noop] - Disables all logging if set to true.
  Logger({
    required this.name,
    required String endpoint,
    required this.token,
    this.passthrough = true,
    this.insecure = false,
    this.noop = false,
  }) : endpoint = insecure
            ? 'http://$endpoint/api/message'
            : 'https://$endpoint/api/message' {
    _startBatcher();
  }

  void debug(String message, [Map<String, String> attrs = const {}]) {
    _log(LogLevel.debug, message, null, attrs);
  }

  void info(String message, [Map<String, String> attrs = const {}]) {
    _log(LogLevel.info, message, null, attrs);
  }

  void warn(String message, [Map<String, String> attrs = const {}]) {
    _log(LogLevel.warning, message, null, attrs);
  }

  void error(String message,
      [Object? error, Map<String, String> attrs = const {}]) {
    _log(LogLevel.error, message, error, attrs);
  }

  Future<void> shutdown() async {
    if (_isShuttingDown) return _shutdownCompleter?.future ?? Future.value();
    _isShuttingDown = true;
    _shutdownCompleter = Completer<void>();

    _batchTimer?.cancel();
    _batchTimer = null;

    await Future.delayed(Duration.zero);

    await _flushBatchIfNeeded(force: true);

    await _logController.close();

    _shutdownCompleter?.complete();
    return _shutdownCompleter!.future;
  }

  void _log(
    LogLevel level,
    String message, [
    Object? error,
    Map<String, String> attrs = const {},
  ]) {
    if (noop) {
      return;
    }

    final combinedAttrs = Map<String, String>.from(attrs);
    if (error != null) {
      combinedAttrs['error'] = error.toString();
    }
    combinedAttrs['service.name'] = name;

    final logMessage = LogMessage(
      timestamp: DateTime.now().toUtc(),
      body: message,
      level: level,
      attributes: combinedAttrs,
    );

    if (!_logController.isClosed) {
      _logController.sink.add(logMessage);
    }

    _maybePassthrough(message);
  }

  void _startBatcher() {
    _logController.stream.listen((logMessage) {
      _logBuffer.add(logMessage);
      if (_logBuffer.length >= maxBatchSize) {
        _flushBatchIfNeeded();
      }
    });

    _batchTimer = Timer.periodic(
      const Duration(milliseconds: batchIntervalMs),
      (_) => _flushBatchIfNeeded(),
    );
  }

  Future<void> _flushBatchIfNeeded({bool force = false}) async {
    if (_logBuffer.isEmpty && !force) {
      return;
    }

    final logsToSend = List<LogMessage>.from(_logBuffer);
    _logBuffer.clear();

    if (logsToSend.isEmpty && !force) {
      return;
    }

    try {
      await _sendBatch(logsToSend);
    } catch (e) {}
  }

  Future<void> _sendBatch(List<LogMessage> logs) async {
    if (logs.isEmpty || noop) {
      return;
    }

    final batch = MessageBatch(
      token: token,
      type: MessageType.logs,
      logs: logs,
    );

    try {
      await post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(batch.toJson()),
      );
    } catch (e) {}
  }

  void _maybePassthrough(String message) {
    if (!passthrough) return;
    print(message);
  }
}
