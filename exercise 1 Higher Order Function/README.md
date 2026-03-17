# Exercise 1: Higher-Order Function

This exercise focuses on creating a custom **Higher-Order Function** in Kotlin and its equivalent in **Dart (Flutter)**. A higher-order function is a function that takes another function as a parameter or returns a function.

## Task
The objective was to write a function named `processList` that filters a list of integers based on a **predicate** (a lambda or closure that returns a Boolean).

### Kotlin Implementation
Instead of using the built-in `.filter()` function, I implemented the logic from scratch to better understand how higher-order functions work under the hood.

```kotlin
fun processList(
    numbers: List<Int>,
    predicate: (Int) -> Boolean
): List<Int> {
    val result = mutableListOf<Int>()
    for (num in numbers) {
        if (predicate(num)) {
            result.add(num)
        }
    }
    return result
}
```

### Dart (Flutter) Implementation
In Dart, we achieve the same behavior by passing a function as a parameter using the `bool Function(int)` type.

```dart
List<int> processList(List<int> numbers, bool Function(int) predicate) {
  final result = <int>[];
  for (final num in numbers) {
    if (predicate(num)) {
      result.add(num);
    }
  }
  return result;
}
```

### Testing the Function
I tested this function with a list of integers and an "even numbers" lambda/closure:

**Kotlin:**
```kotlin
val nums = listOf(1, 2, 3, 4, 5, 6)
val even = processList(nums) { it % 2 == 0 }
// Result: [2, 4, 6]
```

**Dart:**
```dart
final nums = [1, 2, 3, 4, 5, 6];
final even = processList(nums, (num) => num % 2 == 0);
// Result: [2, 4, 6]
```

## UI Showcase
The UI for this exercise displays the input list and the results of different filter predicates applied through my `processList` function.
- **Kotlin Tech Stack**: Jetpack Compose, Material Design 3.
- **Flutter Tech Stack**: Flutter Widgets, Material Design 3.

## How to View
- **Kotlin**: Open `HigherOrderFunction.kt` in Android Studio and check the `HigherOrderPreview`.
- **Flutter**: Open `exercise1.dart` and run it in a Dart-enabled IDE or via the command line with `dart exercise1.dart`.

---
**Implemented by: Madongue Jeanne Lesline**
