/**
 * Project Milestone 3: Object-Oriented Domain Model
 * Student: Madongue Jeanne Lesline
 * 
 * Requirements:
 * 1. Create at least three classes with proper inheritance or interface implementation.
 * 2. Use an abstract class or interface to define common behavior.
 * 3. Include at least one data class.
 * 4. Override toString() in at least one class (or rely on data class).
 * 5. Demonstrate polymorphism by storing different subclass instances in a collection 
 *    and calling overridden methods.
 * 6. Write a short main() that showcases your hierarchy.
 */

// 1. Interface defining common grading behavior
interface Gradeable {
    fun getGrade(): String
    fun getStatus(): String
}

// 2. Abstract class representing a generic Course Participant
abstract class Participant(val name: String, val id: String) {
    // Abstract method for polymorphism
    abstract fun showProfile()
    
    // Basic toString override
    override fun toString(): String {
        return "Participant[Name: $name, ID: $id]"
    }
}

// 3. Data Class (Requirement: At least one data class)
// Represents a Student, inheriting from Participant and implementing Gradeable
data class Student(
    val studentName: String,
    val studentId: String,
    val score: Double
) : Participant(studentName, studentId), Gradeable {

    override fun getGrade(): String {
        return when {
            score >= 90 -> "A"
            score >= 80 -> "B"
            score >= 70 -> "C"
            score >= 60 -> "D"
            else -> "F"
        }
    }

    override fun getStatus(): String {
        return if (score >= 60) "Passed" else "Failed"
    }

    override fun showProfile() {
        println("STUDENT PROFILE: $studentName ($studentId) | Grade: ${getGrade()} | Status: ${getStatus()}")
    }
    
    // Data class automatically provides a useful toString() implementation
}

// 4. Another class representing a Teacher, inheriting from Participant
class Teacher(
    name: String,
    id: String,
    val subject: String
) : Participant(name, id) {

    override fun showProfile() {
        println("TEACHER PROFILE: $name ($id) | Subject: $subject")
    }

    // Explicit toString override
    override fun toString(): String {
        return "Teacher[Name: $name, Subject: $subject]"
    }
}

// 5. Another class representing a Guest Lecturer, inheriting from Participant
class GuestLecturer(
    name: String,
    id: String,
    val institution: String
) : Participant(name, id) {

    override fun showProfile() {
        println("GUEST LECTURER: $name from $institution")
    }
}

// 6. Main function showcasing the domain model
fun main() {
    println("=== Grade Calculator Domain Model Showcase (Milestone 3) ===")

    // Create a collection of different Participant subclasses (Polymorphism)
    val members: List<Participant> = listOf(
        Student("Madongue Jeanne Lesline", "S001", 95.5),
        Teacher("Dr. Smith", "T101", "Software Engineering"),
        Student("Alice Brown", "S002", 58.0),
        GuestLecturer("Prof. Miller", "G001", "MIT"),
        Student("Bob Wilson", "S003", 82.0)
    )

    println("\n1. Demonstrating Polymorphism via showProfile():")
    members.forEach { member ->
        // This calls the specific implementation in Student, Teacher, or GuestLecturer
        member.showProfile()
        
        // Demonstrating interface usage through polymorphism
        if (member is Gradeable) {
            println("   -> Grading Insight: Score of ${member.getGrade()} means this student ${member.getStatus()}")
        }
    }

    println("\n2. Demonstrating toString() Overrides / Data Class behavior:")
    members.forEach { member ->
        println("   Log entry: $member")
    }
}
