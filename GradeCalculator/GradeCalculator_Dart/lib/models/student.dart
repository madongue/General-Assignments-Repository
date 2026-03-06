class Student {
  final int? id;
  final String name;
  final double? score;
  final String grade;

  Student({
    this.id,
    required this.name,
    this.score,
    required this.grade,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'score': score,
      'grade': grade,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'],
      name: map['name'],
      score: map['score'],
      grade: map['grade'],
    );
  }
}
