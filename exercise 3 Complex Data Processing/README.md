# Exercise 3: Complex Data Processing

This exercise demonstrates a real-world scenario of processing a collection of data objects using a chain of functional transformations.

## Task
Given a list of `Person` objects (containing names and ages), I needed to:
1.  Filter the list to include only people whose names start with **'A'** or **'B'**.
2.  Extract their ages.
3.  Calculate the **average age** of this filtered group.
4.  Display the result rounded to **one decimal place**.

### My Implementation
I used a combination of `filter`, `map`, and `average` to solve this in a concise, readable manner.

```kotlin
data class Person(val name: String, val age: Int)

val people = listOf(...)

// The processing chain
val averageAge = people
    .filter { it.name.startsWith("A") || it.name.startsWith("B") }
    .map { it.age }
    .average()

// Formatting the result
val formatted = String.format("%.1f", averageAge)
```

## UI Showcase
The UI for this project is designed as a **data summary dashboard**:
- **Hero Card**: Displays the final calculated average age in a large, bold font.
- **Processing Flow**: A vertical timeline-style visualization showing how the data was filtered from the original set.
- **Results List**: A list of the specific individuals (Alice, Bob, Anna, Ben) who were included in the calculation, each with a custom avatar.
- **Tech Stack**: Built using **Jetpack Compose** with **Material Design 3**.

## How to View
Check out `ComplexDataProcessing.kt` and use the **Compose Preview** to see the data dashboard in action.
