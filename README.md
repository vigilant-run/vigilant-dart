# Vigilant Dart SDK

This is the Dart SDK for the Vigilant platform.

## Installation

```bash
dart pub add vigilant
```

## Usage (Logger)

```dart
import 'package:vigilant/vigilant.dart';

// Create the logger
final logger = Logger(
  endpoint: 'https://api.vigilant.run',
  token: 'your-token',
);

// Send a message to the logger
logger.info('Hello, World!');

// Shutdown the logger
await logger.shutdown();
```
