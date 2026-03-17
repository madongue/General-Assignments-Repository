# Filtering and Transforming with Lambdas

This is a project I developed to practice functional programming concepts using lambda expressions in both Kotlin and **Dart (Flutter)**.

## Problem Statement
The goal was to take a predefined list of numbers and perform specific operations using a concise lambda chain:
1.  **Filter**: Remove all numbers less than or equal to 5.
2.  **Transform**: Square each of the remaining numbers.
3.  **Display**: Show the final results in a clean user interface.

## My Kotlin Solution
I implemented the core logic using Kotlin's collection functions:

```kotlin
val numbers = listOf(1, 4, 7, 3, 9, 2, 8)

val results = numbers
    .filter { it > 5 }  // Keep only numbers greater than 5
    .map { it * it }    // Square each of those numbers
```

## My Dart (Flutter) Solution
In Dart, we achieve the same behavior by using `where` and `map` on the list.

```dart
final numbers = [1, 4, 7, 3, 9, 2, 8];

final results = numbers
    .where((num) => num > 5)  // Keep numbers > 5
    .map((num) => num * num) // Square each number
    .toList();               // Convert back to a list
```

## UI Implementation
I built a full UI for this exercise using **Jetpack Compose** (Kotlin) and **Flutter Widgets** (Dart). The interface includes:
- **Visual Flow**: A step-by-step breakdown showing the "Original Data", the "Filtered Result", and the "Final Squared Result".
- **Responsive Layout**: Used `LazyColumn` (Kotlin) and `ListView` (Flutter) to efficiently display the list of processed numbers.
- **Styling**: Applied Material3 `Card` and `Surface` components for a modern look and feel.

## How to Run
- **Kotlin**: Navigate to `FilteringAndTransforming.kt` and use the **Compose Preview**.
- **Flutter**: Open `filtering_transforming.dart` and run it in a Dart-enabled IDE or via the command line with `dart filtering_transforming.dart`.

---
**Implemented by: Madongue Jeanne Lesline**
