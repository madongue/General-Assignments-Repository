/// Exercise 2: Transforming Between Collection Types
///
/// This Dart implementation demonstrates creating a Map from a List
/// and filtering its entries based on their values.

void main() {
  final words = ['apple', 'cat', 'banana', 'dog', 'elephant'];

  // Step 1: Create a Map (String to Int representing length)
  // map.fromIterable is a common way to create a map from a collection
  final wordMap = { for (var word in words) word : word.length };

  // Step 2: Filter the map entries
  // Dart's Map.removeWhere is in-place, but we'll use entries.where
  // to get a new collection of entries with values > 4
  final filteredEntries = wordMap.entries.where((entry) => entry.value > 4);

  // Collect back into a Map
  final filteredMap = Map.fromEntries(filteredEntries);

  print('Original words: $words');
  print('Word to length map: $wordMap');
  print('Filtered map (length > 4): $filteredMap');
  // Result: {'apple': 5, 'banana': 6, 'elephant': 8}
}
