# Exercise 2: Transforming Between Collection Types

This exercise explores how to transform data between different collection types in Kotlin and **Dart (Flutter)**, specifically moving from a `List` to a `Map`.

## Task
Given a list of strings, I needed to:
1.  Create a map where the **keys** are the strings and the **values** are their lengths.
2.  Filter this map to only keep entries where the length is **greater than 4**.
3.  Display the result.

### My Kotlin Implementation
I used the `associateWith` extension function, which is the perfect tool for creating a map from a collection where the elements serve as keys.

```kotlin
val words = listOf("apple", "cat", "banana", "dog", "elephant")

// Step 1: Create the map (String to Int)
val wordMap = words.associateWith { it.length }

// Step 2: Filter the map entries
val filteredEntries = wordMap.filter { it.value > 4 }

// Resulting in entries for "apple", "banana", and "elephant"
```

### My Dart (Flutter) Implementation
In Dart, we achieve the same behavior by using map comprehensions to create a map from a list, then filtering its entries.

```dart
final words = ['apple', 'cat', 'banana', 'dog', 'elephant'];

// Step 1: Create a Map (String to Int representing length)
final wordMap = { for (var word in words) word : word.length };

// Step 2: Filter the map entries using entries.where()
final filteredEntries = wordMap.entries.where((entry) => entry.value > 4);

// Step 3: Collect back into a Map
final filteredMap = Map.fromEntries(filteredEntries);

// Result: {'apple': 5, 'banana': 6, 'elephant': 8}
```

## UI Showcase
The UI for this exercise provides a clean, visual representation of the transformation:
- **List View**: Displays the original input strings.
- **Filtered Results**: Shows each word that passed the filter, prominently displaying its calculated length in a badge.
- **Kotlin Tech Stack**: Built with **Jetpack Compose** and **Material Design 3**.
- **Flutter Tech Stack**: Built with **Flutter Widgets** and **Material Design 3**.

## How to View
- **Kotlin**: Navigate to `TransformingCollections.kt` and open the **Compose Preview**.
- **Flutter**: Open `exercise2.dart` and run it in a Dart-enabled IDE or via the command line with `dart exercise2.dart`.
