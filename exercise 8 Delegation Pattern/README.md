# Exercise 8: Implement a Logger Using Delegation

This exercise demonstrates the use of the **Delegation Pattern** in Dart.

## Task
- Create a simple logging system using delegation.
- Define an interface `Logger` with a function `log(message: String)`.
- Provide two implementations: `ConsoleLogger` and `FileLogger`.
- Create a class `Application` that delegates logging to a `Logger`.

## Implementation (Dart)

```dart
abstract class Logger {
  void log(String message);
}

class ConsoleLogger implements Logger {
  @override
  void log(String message) {
    print('Console: $message');
  }
}

class FileLogger implements Logger {
  @override
  void log(String message) {
    print('File: $message');
  }
}

class Application implements Logger {
  final Logger _logger;

  Application(this._logger);

  @override
  void log(String message) {
    _logger.log(message);
  }
}
```

## How to Run
Open `logger_delegation.dart` and run it using the Dart SDK:
```bash
dart logger_delegation.dart
```

## Expected Output
```
Console: App started
File: Error occurred
```

---
**Implemented by: Madongue Jeanne Lesline**
