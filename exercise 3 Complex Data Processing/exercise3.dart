/// Exercise 3: Complex Data Processing
///
/// This Dart implementation demonstrates a data processing chain
/// with classes and collection methods.

class Person {
  final String name;
  final int age;

  Person(this.name, this.age);

  @override
  String toString() => 'Person(name: $name, age: $age)';
}

void main() {
  final people = [
    Person('Alice', 25),
    Person('Bob', 32),
    Person('Anna', 44),
    Person('Ben', 19),
    Person('Zack', 30),
    Person('Xavier', 21)
  ];

  // Step 1: Filter names starting with 'A' or 'B'
  // Step 2: Extract their ages (map)
  // Step 3: Calculate the average age
  final filteredAges = people
      .where((person) => person.name.startsWith('A') || person.name.startsWith('B'))
      .map((person) => person.age);

  // Dart doesn't have an .average() extension by default, so we use reduce
  final totalAge = filteredAges.fold(0, (sum, age) => sum + age);
  final averageAge = filteredAges.isEmpty ? 0 : totalAge / filteredAges.length;

  // Step 4: Display the result rounded to one decimal place
  final formatted = averageAge.toStringAsFixed(1);

  print('People: $people');
  print('Average Age of names starting with A or B: $formatted'); // Result: 30.0
}
