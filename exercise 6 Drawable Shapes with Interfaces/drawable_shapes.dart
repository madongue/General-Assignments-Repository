/// Exercise 6: Drawable Shapes with Interfaces
/// 
/// Task: Define an interface Drawable with a function draw().
/// Create classes Circle and Square that implement Drawable.
/// Each should have appropriate properties (radius, side length) 
/// and print a simple ASCII representation.

abstract class Drawable {
  void draw();
}

class Circle implements Drawable {
  final int radius;

  Circle(this.radius);

  @override
  void draw() {
    print("Circle with radius $radius:");
    print("  ***  ");
    print(" *   * ");
    print(" *   * ");
    print("  ***  ");
  }
}

class Square implements Drawable {
  final int sideLength;

  Square(this.sideLength);

  @override
  void draw() {
    print("Square with side length $sideLength:");
    print("*******");
    print("*     *");
    print("*     *");
    print("*******");
  }
}

void main() {
  final shapes = <Drawable>[
    Circle(5),
    Square(10),
  ];

  for (final shape in shapes) {
    shape.draw();
  }
}
