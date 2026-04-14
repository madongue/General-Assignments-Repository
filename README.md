# General Assignments Repository

This repository contains a collection of programming exercises and mini-projects developed to master functional programming, OOP, and state management in both **Kotlin (Android)** and **Dart (Flutter)**.

## Table of Contents
- [Exercises](#exercises)
- [Projects](#projects)
- [Technologies Used](#technologies-used)
- [Maintainer](#maintainer)

## Exercises

### 1. [Exercise 1: Higher-Order Function](./exercise%201%20Higher%20Order%20Function/)
- **Concept**: Creating custom higher-order functions that take predicates as parameters.
- **Kotlin/Dart**: Custom `processList` function using lambdas/closures.

### 2. [Exercise 2: Transforming Between Collection Types](./exercise%202%20Transforming%20Between%20Collection%20Types/)
- **Concept**: Data transformation from `List` to `Map` and filtering entries.
- **Kotlin/Dart**: Using `associateWith` and map comprehensions with filtering.

### 3. [Exercise 3: Complex Data Processing](./exercise%203%20Complex%20Data%20Processing/)
- **Concept**: Chaining multiple collection transformations on custom data objects.
- **Kotlin/Dart**: Chaining `filter`/`where`, `map`, and `average`/`fold` on `Person` objects.

### 4. [Filtering and Transforming with Lambdas](./filtering%20and%20transforming%20with%20lambdas/)
- **Concept**: Basic functional operations like filtering and mapping.
- **Kotlin/Dart**: Concise chains to filter and square integers.

### 5. [Exercise 4: Model a Zoo](./exercise%204%20Model%20a%20Zoo/)
- **Concept**: Inheritance, abstract classes, and polymorphism.
- **Dart**: Class hierarchy with `Animal`, `Dog`, and `Cat`.

### 6. [Exercise 5: Model Network Request State with Sealed Class](./exercise%205%20Network%20Request%20State/)
- **Concept**: State management using sealed classes and exhaustive switch cases.
- **Dart**: Modeling `Loading`, `Success`, and `Error` states.

### 7. [Exercise 6: Drawable Shapes with Interfaces](./exercise%206%20Drawable%20Shapes%20with%20Interfaces/)
- **Concept**: Interface implementation and ASCII representation.
- **Dart**: `Drawable` interface with `Circle` and `Square` implementations.

### 8. [Exercise 7: Generic Function with Constraints](./exercise%207%20Generic%20Function/)
- **Concept**: Using Generics with Type Constraints (Comparable).
- **Dart**: A `maxOf` function that works with any Comparable type.

### 9. [Exercise 8: Implement a Logger Using Delegation](./exercise%208%20Delegation%20Pattern/)
- **Concept**: The Delegation Pattern for swapping implementations easily.
- **Dart**: `Application` class delegating logging to `ConsoleLogger` or `FileLogger`.

## Projects

### FocusFlow Project
- **Description**: Digital wellbeing and productivity application tailored for students. Monitors environment and posture using smartphone sensors.
- **Lead Developer**: Madongue Jeanne Lesline.

### Grade Calculator Project
- **Description**: Comprehensive tool for calculating and managing student grades using OOP principles. Supports CSV imports and automated grading.
- **Maintainer**: Madongue Jeanne Lesline.

## Technologies Used
- **Android**: Kotlin, Jetpack Compose, Material Design 3.
- **Flutter**: Dart, Flutter SDK, Material Design 3.

---
**Maintained by: Madongue Jeanne Lesline**
# FocusFlow

> Digital Wellbeing & Productivity Application for Students  
> **Course:** Android Application Development - ICT University  
> **Lead Developer:** NGUEND ARTHUR JOHANN (ICTU20223180)  
> **Quality Test Developer:** MADONGUE JEANNE LESLINE (ICTU20222931)  
> **Milestone:** 1 - Core Data Model  
> **Date:** February 27, 2026

---

## 1. Project Overview

FocusFlow is a digital wellbeing and productivity application tailored for students. The app monitors users' physical environment and study habits in real time to reduce health risks such as digital eye strain, postural disorders, cognitive fatigue, and sedentary behavior. By leveraging sensors available in smartphones, FocusFlow acts as a proactive health coach, transforming a potential source of distraction into a positive productivity tool.

---

## 2. Problem Statement

Students frequently face physical and cognitive challenges during lengthy study sessions, including:

- **Digital Eye Strain**: Poor lighting and improper screen distance lead to eye discomfort.
- **Postural Disorders**: The "text-neck" posture contributes to chronic neck and back pain.
- **Cognitive Overload**: Environmental noise disrupts concentration and the "flow" state.
- **Sedentary Behavior**: Extended periods of inactivity affect brain oxygenation and overall focus.

FocusFlow addresses these issues by monitoring and recording environmental and behavioral data, providing actionable feedback to promote healthier study sessions.

---

## 3. Technical Requirements

### 3.1 Hardware Requirements

- **Ambient Light Sensor**: Monitors environmental brightness.
- **Front Camera**: Used for face detection and screen distance estimation.
- **Microphone**: Measures real-time noise levels (dB).
- **3-Axis Accelerometer**: Tracks physical inactivity.

### 3.2 Software Stack

- **Language:** Kotlin 1.9+
- **Min SDK:** Android 8.0 (API Level 26)
- **Architecture:** MVVM (Model-View-ViewModel)
- **Key Libraries:**  
    - Google ML Kit (Face Detection)  
    - Room Persistence  
    - Kotlin Coroutines

---

## 4. Milestone 1: Core Data Model

```kotlin
/**
 * PROJECT: FocusFlow
 * MILESTONE: 1 - Data Modeling
 */

data class FocusState(
    val lightLevelLux: Double?, 
    val faceDistanceCm: Double?, 
    val noiseDb: Double, 
    val isSedentary: Boolean,
    val sessionID: String
)

fun main() {
    // Instance 1: Optimal Conditions
    val optimalState = FocusState(
        lightLevelLux = 450.0, 
        faceDistanceCm = 55.0, 
        noiseDb = 25.0, 
        isSedentary = false,
        sessionID = "SESSION_001"
    )

    // Instance 2: Health Warning
    val warningState = FocusState(
        lightLevelLux = 80.0, 
        faceDistanceCm = 15.0, 
        noiseDb = 35.0, 
        isSedentary = true,
        sessionID = "SESSION_001"
    )

    // Instance 3: Sensor Error Case
    val errorState = FocusState(
        lightLevelLux = null, 
        faceDistanceCm = null, 
        noiseDb = 15.0, 
        isSedentary = false,
        sessionID = "SESSION_002"
    )

    println("State 1: $optimalState")
    println("State 2: $warningState")
    println("State 3: $errorState")
}
```

---

## 5. Technical Justification

- **Kotlin Data Classes** facilitate efficient and robust data management.
- **Nullability** for `lightLevelLux` and `faceDistanceCm` ensures graceful handling if hardware sensors are unavailable.
- **Immutable Values (val)** preserve the integrity of sensor snapshots, preventing accidental alteration and supporting accurate session logging for future analytics and feedback (Milestone 2).

---

## 6. Development Milestones

- **Milestone 1:** Core Data Model (completed)
- **Milestone 2:** Advanced session logging and analytics (upcoming)
- **Milestone 3:** Real-time feedback and health alerts (upcoming)

---

## 7. License

This project is intended for educational purposes under the ICT University Android Application Development course.

---

## 8. Contact

- NGUEND ARTHUR JOHANN (ICTU20223180)
- MADONGUE JEANNE LESLINE (ICTU20222931)
