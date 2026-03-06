# Exercise 2: Transforming Between Collection Types

This exercise explores how to transform data between different collection types in Kotlin, specifically moving from a `List` to a `Map`.

## Task
Given a list of strings, I needed to:
1.  Create a map where the **keys** are the strings and the **values** are their lengths.
2.  Filter this map to only keep entries where the length is **greater than 4**.
3.  Display the result.

### My Implementation
I used the `associateWith` extension function, which is the perfect tool for creating a map from a collection where the elements serve as keys.

```kotlin
val words = listOf("apple", "cat", "banana", "dog", "elephant")

// Step 1: Create the map (String to Int)
val wordMap = words.associateWith { it.length }

// Step 2: Filter the map entries
val filteredEntries = wordMap.filter { it.value > 4 }

// Resulting in entries for "apple", "banana", and "elephant"
```

## UI Showcase
The UI for this exercise provides a clean, visual representation of the transformation:
- **List View**: Displays the original input strings.
- **Filtered Results**: Shows each word that passed the filter, prominently displaying its calculated length in a badge.
- **Tech Stack**: Built with **Jetpack Compose** and **Material Design 3**.

## How to View
Navigate to `TransformingCollections.kt` and open the **Compose Preview** to see the interactive result cards.
