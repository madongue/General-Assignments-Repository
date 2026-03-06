# Filtering and Transforming with Lambdas

This is a small Kotlin/Android project I developed to practice functional programming concepts using lambda expressions.

## Problem Statement
The goal was to take a predefined list of numbers and perform specific operations using a concise lambda chain:
1.  **Filter**: Remove all numbers less than or equal to 5.
2.  **Transform**: Square each of the remaining numbers.
3.  **Display**: Show the final results in a clean user interface.

## My Solution
I implemented the core logic using Kotlin's collection functions:

```kotlin
val numbers = listOf(1, 4, 7, 3, 9, 2, 8)

val results = numbers
    .filter { it > 5 }  // Keep only numbers greater than 5
    .map { it * it }    // Square each of those numbers
```

## UI Implementation
I built a full UI for this exercise using **Jetpack Compose** and **Material Design 3**. The interface includes:
- **Visual Flow**: A step-by-step breakdown showing the "Original Data", the "Filtered Result", and the "Final Squared Result".
- **Responsive Layout**: Used `LazyColumn` to efficiently display the list of processed numbers.
- **Styling**: Applied Material3 `Card` and `Surface` components for a modern look and feel.

## How to Run
1. Open this project in Android Studio.
2. Navigate to `FilteringAndTransforming.kt`.
3. Use the **Compose Preview** (`FilteringExercisePreview`) to see the UI immediately without needing a full device deployment.
