/// Exercise 8: Implement a Logger Using Delegation
/// 
/// Task: Create a simple logging system using the delegation pattern.
/// 1. Define an interface Logger with a function log(String message).
/// 2. Provide two implementations: ConsoleLogger and FileLogger.
/// 3. Create a class Application that delegates logging to a Logger.

// 1. Interface defining the logging behavior
abstract class Logger {
  void log(String message);
}

// 2. Concrete implementation: Console Logger
class ConsoleLogger implements Logger {
  @override
  void log(String message) {
    print('Console: $message');
  }
}

// 2. Concrete implementation: File Logger (simulated)
class FileLogger implements Logger {
  @override
  void log(String message) {
    print('File: $message');
  }
}

// 3. Class Application using the delegation pattern
// In Dart, we manually delegate the call to the logger instance.
class Application implements Logger {
  final Logger _logger;

  Application(this._logger);

  @override
  void log(String message) {
    // Delegation in action
    _logger.log(message);
  }
}

void main() {
  print('--- Exercise 8: Delegation Pattern ---');

  // Using ConsoleLogger
  final app = Application(ConsoleLogger());
  app.log('App started'); // Expected: Console: App started

  // Using FileLogger
  final fileApp = Application(FileLogger());
  fileApp.log('Error occurred'); // Expected: File: Error occurred
}
