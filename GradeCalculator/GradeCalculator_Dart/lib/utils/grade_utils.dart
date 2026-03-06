class GradeUtils {
  static String calculateGrade(double? score) {
    if (score == null) return 'No Grade';
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  static String getPerformance(double? score) {
    if (score == null) return 'No score for student';
    if (score >= 90) return 'Excellent';
    if (score >= 80) return 'Very Good';
    if (score >= 70) return 'Good';
    if (score >= 60) return 'Pass';
    return 'Fail';
  }

  static String formatScore(double? score) {
    return score?.toString() ?? 'No score';
  }
}
