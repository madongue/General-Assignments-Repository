/// Exercise 5: Model Network Request State with Sealed Class
/// 
/// Task: Define a sealed class NetworkState representing:
/// - Loading
/// - Success(data: String)
/// - Error(message: String)
/// - Write a function handleState(state: NetworkState) that prints appropriate messages.

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

void main() {
  final states = <NetworkState>[
    Loading(),
    Success('User data loaded'),
    Error('Network timeout'),
  ];

  for (final state in states) {
    handleState(state);
  }
}
