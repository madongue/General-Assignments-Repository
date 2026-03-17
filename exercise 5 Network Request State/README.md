# Exercise 5: Model Network Request State with Sealed Class

This exercise demonstrates the use of **sealed classes** in Dart to manage network request states in an exhaustive and type-safe way.

## Task
- Define a sealed class `NetworkState` representing:
  - `Loading`
  - `Success(data: String)`
  - `Error(message: String)`
- Write a function `handleState(state: NetworkState)` that prints appropriate messages for each state.

## Implementation (Dart)

```dart
sealed class NetworkState {}

class Loading extends NetworkState {}

class Success extends NetworkState {
  final String data;
  Success(this.data);
}

class Error extends NetworkState {
  final String message;
  Error(this.message);
}

void handleState(NetworkState state) {
  switch (state) {
    case Loading():
      print('Loading...');
    case Success(:final data):
      print('Success: $data');
    case Error(:final message):
      print('Error: $message');
  }
}
```

## How to Run
Open `network_state.dart` and run it using the Dart SDK:
```bash
dart network_state.dart
```

## Expected Output
```
Loading...
Success: User data loaded
Error: Network timeout
```
