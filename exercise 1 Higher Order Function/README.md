# Exercise 1: Higher-Order Function

This exercise focuses on creating a custom **Higher-Order Function** in Kotlin. A higher-order function is a function that takes another function as a parameter or returns a function.

## Task
The objective was to write a function named `processList` that filters a list of integers based on a **predicate** (a lambda that returns a Boolean).

### My Implementation
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

### Testing the Function
I tested this function with a list of integers and an "even numbers" lambda:

```kotlin
val nums = listOf(1, 2, 3, 4, 5, 6)
val even = processList(nums) { it % 2 == 0 }
// Result: [2, 4, 6]
```

## UI Showcase
The UI for this exercise displays the input list and the results of different filter predicates applied through my `processList` function.
- **Tech Stack**: Jetpack Compose, Material Design 3.
- **Visuals**: Clean cards with result badges and clear labeling of the predicates used.

## How to View
Open `HigherOrderFunction.kt` in Android Studio and check the `HigherOrderPreview` to see the results of the implementation.
