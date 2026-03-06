/// Filtering and Transforming with Lambdas
///
/// This Dart implementation shows how to use the .where() and .map()
/// collection methods for functional data transformation.

void main() {
  final numbers = [1, 4, 7, 3, 9, 2, 8];

  // Step 1: Filter (Remove numbers <= 5)
  // Step 2: Transform (Square each remaining number)
  final results = numbers
      .where((num) => num > 5)  // Keep numbers > 5
      .map((num) => num * num) // Square each number
      .toList();               // Convert back to a list

  print('Original numbers: $numbers');
  print('Processed results (squared and > 5): $results');
  // Result: [49, 81, 64]
}
