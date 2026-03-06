/// Exercise 1: Higher-Order Function
///
/// This Dart implementation demonstrates a custom higher-order function
/// equivalent to the Kotlin version.

List<int> processList(List<int> numbers, bool Function(int) predicate) {
  final result = <int>[];
  for (final num in numbers) {
    if (predicate(num)) {
      result.add(num);
    }
  }
  return result;
}

void main() {
  final nums = [1, 2, 3, 4, 5, 6];

  // Using the custom processList function with a closure (lambda)
  final even = processList(nums, (num) => num % 2 == 0);

  print('Original numbers: $nums');
  print('Even numbers: $even'); // Result: [2, 4, 6]
}
