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
