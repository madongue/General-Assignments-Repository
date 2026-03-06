/// Base abstract class demonstrating Abstraction and Inheritance.
abstract class Calculator {
  final String name;

  Calculator(this.name);

  /// Abstract method that must be implemented by subclasses.
  String calculate(double? input);
}
