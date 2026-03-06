# Student Grade Calculator Mobile Application (Kotlin)

## Overview

The **Student Grade Calculator** is a native Android application developed in Kotlin, designed to streamline the calculation and display of student grades through both manual entry and Excel file imports. Featuring a highly intuitive graphical user interface, robust data validation, and multi-format import/export capabilities, this application is built as a comprehensive academic support tool for students, teachers, and educational administrators.

This project exemplifies critical Android development skills, including file handling, user interface design, local data storage, multilingual support, and basic data analytics.

---

## Features

### 1. Interactive Graphical User Interface (GUI)
- Clean, responsive UI using Android components.
- Manual entry of student names and scores.
- Immediate visibility of calculated grades.
- Easy navigation between input, results, and statistics.
- Structured display for entered and imported data.

### 2. Excel File Import System
- Import Excel spreadsheets containing multiple student records.
- Automated extraction of names and scores, real-time data validation.
- Instant calculation and display of grades.
- Clear error messages for invalid formats.

### 3. Automated Grade Calculation Engine
- Conditional grading logic (`if`/`when` statements) customized to institutional grading scales.
- Immediate feedback on student performance.

### 4. Export Functionality (PDF & Excel)
- Export processed results as PDF reports or Excel spreadsheets.
- Ideal for report generation, data sharing, or archiving.

### 5. Grading Statistics Dashboard
- Automatic computation and display of:
  - Average, highest, and lowest scores.
  - Performance summaries and class insights.

### 6. Local Data Storage
- Persistent storage via SQLite or Room Database.
- Offline access to historical and in-progress records.
- No need for repeat uploads or constant connectivity.

### 7. Multi-Language Support
- Switch between supported languages (example: English and French) from the settings menu.
- Dynamic, real-time UI localization for broader accessibility.

### 8. Robust Data Validation and Error Handling
- Ensures only numeric marks within valid ranges are processed.
- Handles empty/invalid fields safely.
- Clear alerts for Excel format errors or import issues.

---

## Objectives

- **Demonstrate** effective Android development and Kotlin programming.
- **Provide** a user-friendly, responsive, and reliable grade calculation platform.
- **Enable** easy file import/export operations.
- **Support** multilingual accessibility and offline data persistence.
- **Deliver** actionable academic performance insights via statistics and reporting.

---

## Technical Implementation

- **Language:** Kotlin
- **Platform:** Android
- **Architecture:** Modular (separates UI, logic, and data layers)
- **UI:** Android XML layouts and/or Jetpack Compose
- **Data Modeling:** Kotlin data classes (StudentRecord, etc.)
- **Excel Parsing:** Utilizes libraries such as Apache POI
- **Database:** SQLite or Room for local data persistence
- **Localization:** Android internationalization framework
- **File Handling:** Integrated file picker for import/export operations
- **Error Handling:** Comprehensive validation at every stage

---

## Educational and Practical Value

This project demonstrates core competencies in:
- Modern Android application development
- Data parsing and manipulation (Excel, PDF)
- UI/UX design and accessibility
- Data persistence and offline usage
- Real-world localization practices
- Statistical computation and reporting
- Collaborative development and learning (e.g., pair programming)

---

## Expected Outcomes

Upon completion, the application will be capable of:
- Instantly calculating grades from manual or Excel-based student entries
- Presenting results and analytics in a clear, structured manner
- Exporting data to shareable PDFs or Excel files
- Preserving records locally for future reference
- Supporting multiple languages for broader reach
- Handling invalid data and file errors gracefully

---

## Getting Started

1. **Clone the Repository:**
   ```sh
   git clone https://github.com/NGUEND-ARTHUR/GradeCalculator.git
   ```

2. **Open in Android Studio:**  
   Open the project folder and allow Gradle to sync.

3. **Build & Run:**  
   Install requirements (latest Android SDK, Kotlin) and run the app on your device or emulator.

4. **Test Scenarios:**  
   - Try manual entry of student grades.
   - Import a sample Excel file (see `/samples/`).
   - Export results to PDF or Excel.
   - Switch languages in the settings menu.

---

## Contributing

Contributions, issues, and feature requests are welcome!  
Please [open an issue](https://github.com/NGUEND-ARTHUR/GradeCalculator/issues) to discuss improvements or report bugs.

---

## License

Distributed under the MIT License. See `LICENSE` for more information.

---

## Acknowledgements

- [Apache POI](https://poi.apache.org/) for Excel file processing
- Android Jetpack Libraries (Room, Compose, etc.)
- Community contributors and open-source tools that support the app’s development

---

> **This project serves as a practical educational tool and an advanced portfolio piece, demonstrating strong Android and Kotlin development skills in real-world scenarios.**