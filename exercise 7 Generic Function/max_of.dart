/// Exercise 7: Generic Function with Constraints
/// 
/// Task: Write a generic function maxOf that returns the maximum element from a list.
/// The function works for any type T that extends Comparable<T>.

T? maxOf<T extends Comparable<T>>(List<T> list) {
  if (list.isEmpty) return null;
  
  T currentMax = list[0];
  for (var i = 1; i < list.length; i++) {
    if (list[i].compareTo(currentMax) > 0) {
      currentMax = list[i];
    }
  }
  return currentMax;
}

void main() {
  print('--- Exercise 7: Generic maxOf Function ---');
  
  final intList = [3, 7, 2, 9];
  print('Max of $intList: ${maxOf(intList)}'); // Expected: 9

  final stringList = ['apple', 'banana', 'kiwi'];
  print('Max of $stringList: ${maxOf(stringList)}'); // Expected: kiwi

  final emptyList = <int>[];
  print('Max of empty list: ${maxOf(emptyList)}'); // Expected: null
}
