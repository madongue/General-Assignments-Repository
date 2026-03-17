# Exercise 7: Generic Function with Constraints

This exercise demonstrates the use of **Generics** and **Type Constraints** in Dart.

## Task
- Write a generic function `maxOf` that returns the maximum element from a list.
- The function should work for any type `T` that implements `Comparable<T>`.
- Handle empty lists by returning `null`.

## Implementation (Dart)

```dart
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
```

## How to Run
Open `max_of.dart` and run it using the Dart SDK:
```bash
dart max_of.dart
```

## Expected Output
```
Max of [3, 7, 2, 9]: 9
Max of [apple, banana, kiwi]: kiwi
Max of empty list: null
```

---
**Implemented by: Madongue Jeanne Lesline**
