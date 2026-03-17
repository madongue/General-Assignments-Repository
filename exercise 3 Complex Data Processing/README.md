# Exercise 3: Complex Data Processing

This exercise demonstrates a real-world scenario of processing a collection of data objects using a chain of functional transformations in both Kotlin and **Dart (Flutter)**.

## Task
Given a list of `Person` objects (containing names and ages), I needed to:
1.  Filter the list to include only people whose names start with **'A'** or **'B'**.
2.  Extract their ages.
3.  Calculate the **average age** of this filtered group.
4.  Display the result rounded to **one decimal place**.

### My Kotlin Implementation
I used a combination of `filter`, `map`, and `average` to solve this in a concise, readable manner.

```kotlin
data class Person(val name: String, val age: Int)

val averageAge = people
    .filter { it.name.startsWith("A") || it.name.startsWith("B") }
    .map { it.age }
    .average()

val formatted = String.format("%.1f", averageAge)
```

### My Dart (Flutter) Implementation
In Dart, we achieve the same result using a combination of `where`, `map`, and `fold` for calculating the average.

```dart
class Person {
  final String name;
  final int age;
  
  Person(this.name, this.age);
}

final filteredAges = people
    .where((person) => person.name.startsWith('A') || person.name.startsWith('B'))
    .map((person) => person.age);

final totalAge = filteredAges.fold(0, (sum, age) => sum + age);
final averageAge = filteredAges.isEmpty ? 0 : totalAge / filteredAges.length;

final formatted = averageAge.toStringAsFixed(1);
```

## UI Showcase
The UI for this project is designed as a **data summary dashboard**:
- **Hero Card**: Displays the final calculated average age in a large, bold font.
- **Processing Flow**: A vertical timeline-style visualization showing how the data was filtered from the original set.
- **Kotlin Tech Stack**: Built using **Jetpack Compose** with **Material Design 3**.
- **Flutter Tech Stack**: Built with **Flutter Widgets** and **Material Design 3**.

## How to View
- **Kotlin**: Check out `ComplexDataProcessing.kt` and use the **Compose Preview**.
- **Flutter**: Open `exercise3.dart` and run it in a Dart-enabled IDE or via the command line with `dart exercise3.dart`.

---
**Implemented by: Madongue Jeanne Lesline**
