# Exercise 6: Drawable Shapes with Interfaces

This exercise explores how to use **interfaces** (using abstract classes in Dart) to define common behavior for different object types.

## Task
- Define an interface `Drawable` with a `draw()` method.
- Create `Circle` and `Square` classes that implement `Drawable`.
- Each class should have its own properties (`radius` or `side length`) and print a simple ASCII representation.

## Implementation (Dart)

```dart
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
```

## How to Run
Open `drawable_shapes.dart` and run it using the Dart SDK:
```bash
dart drawable_shapes.dart
```

## Expected Output
```
Circle with radius 5:
  ***  
 *   * 
 *   * 
  ***  
Square with side length 10:
*******
*     *
*     *
*******
```
